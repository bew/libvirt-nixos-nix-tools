{ nixpkgs ? import <nixpkgs> {},
}:

let

  # Builds a derivation including the network definition's XML and a script
  # to recreate the network.
  makeLibvirtNetwork =
    { name,
      xmlDefinition,
    }:

    let

      networkDefinitionXML = nixpkgs.writeText "libvirt-network--${name}.xml" xmlDefinition;

      recreateNetworkScript = nixpkgs.writeScript "recreate-libvirt-network--${name}"
        ''
          set -e

          ${./recreate-network.sh} "${name}" ${networkDefinitionXML}

          echo
          echo "   The network ${name} has been recreated!"
          echo
          echo "   You will need to restart the libvirt domains attached to it."
          echo
        '';

    in nixpkgs.runCommand "libvirt-network--${name}" {}
      ''
        mkdir -p $out/bin
        ln -s ${recreateNetworkScript} $out/bin/recreate-libvirt-network--${name}
        ln -s ${networkDefinitionXML} $out/libvirt-network--${name}.xml
      '';

  blockIPAndDHCP =
    { ip, dhcp }:
    if (ip ? addr) && (ip ? mask) && (dhcp ? start) && (dhcp ? end)
    then ''
      <ip address="${ip.addr}" netmask="${ip.mask}">
        <dhcp>
          <range start="${dhcp.start}" end="${dhcp.end}"/>
        </dhcp>
      </ip>
    ''
    else "";

in rec {
  # Builds a derivation with an isolated network XML definition and a script
  # to recreate it in libvirt.
  makeIsolatedNetwork =
    { name, ip, dhcp }:
    makeLibvirtNetwork {
      inherit name;

      xmlDefinition =
        ''
          <network>
            <name>${name}</name>
            ${blockIPAndDHCP {inherit ip dhcp;} }
          </network>
        '';
    };

  makeIsolatedNetworkIP24 =
    { name, net24bit }:
    makeIsolatedNetwork {
      inherit name;
      ip = { addr = "${net24bit}.0"; mask = "255.255.255.0"; };
      dhcp = { start = "${net24bit}.1"; end = "${net24bit}.254"; };
    };

  # Builds a derivation with a host only network XML definition and a script
  # to recreate it in libvirt.
  makeHostOnlyNetwork =
    { name, bridge, ip, dhcp }:

    makeLibvirtNetwork {
      inherit name;

      xmlDefinition =
        ''
          <network>
            <name>${name}</name>
            <bridge name="${bridge}" />
            ${blockIPAndDHCP {inherit ip dhcp;} }
          </network>
        '';
    };

  makeHostOnlyNetworkIP24 =
    { name, bridge, net24bit }:
    makeHostOnlyNetwork {
      inherit name bridge;
      ip = { addr = "${net24bit}.0"; mask = "255.255.255.0"; };
      dhcp = { start = "${net24bit}.1"; end = "${net24bit}.254"; };
    };
}
