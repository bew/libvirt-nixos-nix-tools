# This file is the VM-specific parts of the config

{ config, pkgs, ... }:

{
  # When the config is evaluated (see ./default.nix) the following config
  # files will be imported as well.
  imports = [
    ./vm-generic.nix
  ];

  # The name of the libvirt domain (and the hostname of the VM)
  libvirt-domain.name = "nixos-vm1";
  networking.hostName = config.libvirt-domain.name; # copy the value above :)
}
