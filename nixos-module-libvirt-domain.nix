{ config, lib, pkgs, ... }:

let

  cfg = config.libvirt-domain;

  # Taken from <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>, seems to be necessary
  # for the value of regInfo kernel param, which is used by qemu-vm's module's boot
  # configuration... Search 'pathsInNixDB' in that file for more info.
  regInfo = pkgs.closureInfo { rootPaths = config.virtualisation.pathsInNixDB; };

  kernelParamsStr = lib.concatStringsSep " " config.boot.kernelParams;

  domainXmlDefinition =
    let cfg-toplevel = config.system.build.toplevel;
    in ''
      <domain type="kvm">
        <name>${cfg.name}</name>
        <memory unit="MiB">${toString cfg.memorySizeMB}</memory>
        <vcpu>${toString cfg.cpuCount}</vcpu>
        <os>
          <type>hvm</type>
          <kernel>${cfg-toplevel}/kernel</kernel>
          <initrd>${cfg-toplevel}/initrd</initrd>
          <cmdline>${kernelParamsStr} init=${cfg-toplevel}/init regInfo=${regInfo} console=ttyS0</cmdline>
        </os>

        <!-- THE DEVICES -->
        <devices>
          <!-- NOTE: does not seems to work with Nix-based qemu, so we use the system one for now (don't remember what was broken) -->
          <!-- <emulator>/nix/store/rmn2kin8pnsgw416iz4d2cy8z89qass6-qemu-host-cpu-only-for-vm-tests-4.2.0/bin/qemu-system-x86_64</emulator> -->
          <emulator>/usr/bin/qemu-system-x86_64</emulator>
          <!-- THIS MEANS IT CANNOT BE USED STANDALONE -->

          <serial type='pty'>
            <target port='0'/>
          </serial>
          <console type='pty'>
            <target type='serial' port='0'/>
          </console>

          <!-- fast random number generator -->
          <rng model='virtio'>
            <rate period="2000" bytes="1234"/>
            <backend model='random'>/dev/random</backend>
          </rng>

          <!-- virtfs for the Nix store -->
          <filesystem type="mount" accessmode="passthrough">
            <source dir="/nix/store" />
            <target dir="store" /> <!-- this is the mount_tag -->
          </filesystem>

          <!-- virtfs for xchg -->
          <filesystem type="mount" accessmode="passthrough">
            <source dir="${cfg.runtime.sharedDir}" />
            <target dir="xchg" /> <!-- this is the mount_tag -->
          </filesystem>

          <!-- virtfs for share (same as xchg, no idea why..) -->
          <filesystem type="mount" accessmode="passthrough">
            <source dir="${cfg.runtime.sharedDir}" />
            <target dir="shared" /> <!-- this is the mount_tag -->
          </filesystem>

          <disk type="file" device="disk">
            <driver name="qemu" type="qcow2" cache="writeback" />
            <source file="${cfg.runtime.diskPath}" />
            <target dev="vda"/>
          </disk>

          <!-- First network interface (eth0) is the control net (e.g: for auto-ssh config) -->
          ${if cfg.controlNetwork != ""
            then ''
              <interface type="network">
                <source network="${cfg.controlNetwork}"/>
              </interface>
            ''
            else ""
          }

          <!-- Second+ network interface (eth1) is for the network topo -->
          ${let
              networkBlocks = lib.flip map cfg.additionalNetworks (networkName: ''
                <interface type="network">
                  <source network="${networkName}"/>
                </interface>
              '');
            in lib.concatStringsSep "\n" networkBlocks
          }
        </devices>
      </domain>
    '';
  domainXmlDefinitionDrv = pkgs.writeText "libvirt-domain--${cfg.name}.xml" domainXmlDefinition;

  recreateVM =
    ''
      # Create a tmp directory for the domain
      mkdir -p "${cfg.runtime.tmpDir}"

      if ! test -e "${cfg.runtime.diskPath}"; then
        ${pkgs.qemu_test}/bin/qemu-img \
          create -f qcow2 "${cfg.runtime.diskPath}" ${toString cfg.diskSizeMB}M || exit 1
      fi

      # Create a directory for exchanging data with the VM.
      mkdir -p "${cfg.runtime.sharedDir}"

      # Recreate the libvirt domain
      ${./recreate-domain.sh} "${cfg.name}" ${domainXmlDefinitionDrv}
    '';
  recreateVMDrv = pkgs.writeScript "recreate-libvirt-domain--${cfg.name}" recreateVM;

  # TODO: move elsewhere! should be in some sort of topology config or similar
  sshToVM =
    # FIXME WARNING: here we use virsh, sort, awk directly, without refering the store
    let
      cfg-hostName = config.networking.hostName;
    in ''
      # virsh sorts by IP and each line starts by a expiration date, so sorting the
      # output with `sort -r` will sort the IPs by expiration date, the last one first.
      #
      # AWK explained: finds the line where $6 == ${cfg-hostName}, then print the CIDR of
      # the first match and exit (to print only the first one).
      cidr=$(virsh net-dhcp-leases ${cfg.controlNetwork} | \
               sort -r | \
               awk -v host_name=${cfg-hostName} '$6 == host_name { print $5; exit }')

      ip=''${cidr%/*} # keep only "1.2.3.4" in "1.2.3.4/24"

      ssh root@$ip
    '';
  sshToVMDrv = pkgs.writeScript "ssh-to-libvirt-domain--${cfg.name}" sshToVM;

in

{
  options = {
    libvirt-domain.name = lib.mkOption {
      type = lib.types.str;
    };

    libvirt-domain.runtime = {
      # FIXME: when to delete?
      tmpDir = lib.mkOption {
        type = lib.types.path;
        default = "/tmp/libvirt-tmpdir-${cfg.name}";
      };

      sharedDir = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.runtime.tmpDir}/shared";
      };

      diskPath = lib.mkOption {
        type = lib.types.path;
        default = "${cfg.runtime.tmpDir}/nixos-disk.qcow2";
      };
    };

    libvirt-domain.memorySizeMB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 512;
    };

    libvirt-domain.cpuCount = lib.mkOption {
      type = lib.types.ints.positive;
      default = 1;
    };

    libvirt-domain.diskSizeMB = lib.mkOption {
      type = lib.types.ints.positive;
      default = 512;
    };

    libvirt-domain.controlNetwork = lib.mkOption {
      description = "Network name used to control the VM (will be at eth0) (disabled if empty)";
      type = lib.types.str;
      default = "";
    };

    libvirt-domain.additionalNetworks = lib.mkOption {
      description = "Additional libvirt networks the VM should be connected to";
      type = lib.types.listOf lib.types.str;
      default = [];
    };
  };

  config = {
    # Ensure that the Nix store is NOT mounted with an overlayfs in the QEMU VM.
    # Otherwise at boot, Stage 2 fails to start (Operation not permitted) :(
    # .. Thinking about this more, I'm not 100% sure why it fails... But I think
    # it's good enough for now, and we don't need a writable store in the VM anyway.
    virtualisation.writableStore = false;

    # When controlNetwork is set, eth0 is the control network and must use DHCP to get
    # an IP automatically.
    #
    # NOTE: this way of writing makes it work when controlNetwork is not set, so that
    # "eth0" is not mentioned in networking.interfaces and does not hang at VM startup!
    networking.interfaces =
      if cfg.controlNetwork != ""
      then { "eth0".useDHCP = true; }
      else {};

    system.build.libvirt-vm = pkgs.runCommand "libvirt-nixos-vm" {}
      ''
        mkdir -p $out/bin
        ln -s ${config.system.build.toplevel} $out/system--${cfg.name}
        ln -s ${recreateVMDrv} $out/bin/recreate-libvirt-domain--${cfg.name}
        ln -s ${domainXmlDefinitionDrv} $out/libvirt-domain--${cfg.name}.xml

        ${if cfg.controlNetwork != ""
          # NOTE for later: this script could be moved outside of the domain config, to the network/topology definition (for example)
          then ''
            ln -s ${sshToVMDrv} $out/bin/ssh-to-libvirt-domain--${cfg.name}
          ''
          else ""
        }
      '';
  };
}
