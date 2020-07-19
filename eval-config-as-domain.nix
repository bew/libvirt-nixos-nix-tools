{ configuration,
  system ? builtins.currentSystem,
  additionalModules ? [],
}:

(import <nixpkgs/nixos/lib/eval-config.nix> {
  inherit system;
  modules = [
    configuration

    ./nixos-module-libvirt-domain.nix

    # Include qemu in the VM as well to not reinvent the wheel for now for some things
    # (like the filesystems, boot, services, kernel modules, etc...)
    <nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>
  ] ++ additionalModules;
}).config

# The built libvirt domain derivation is available in domainConfig.system.build.libvirt-vm
