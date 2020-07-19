let

  # Imports a few libraries & tools
  # TODO: pin to a specific version to avoid breakings
  nixpkgs = import <nixpkgs> {};
  libvirtTools = import ../.. { inherit nixpkgs; };

  # Imports the vm1 configuration file
  # (includes nothing else, more things will be included when this config
  # is evaluated below)
  config = import ./vm1.nix;

  # Evaluates the final config as a libvirt domain
  completeConfig = libvirtTools.evalConfigAsDomain {
    configuration = config;
  };

in completeConfig.system.build.libvirt-vm
# '...libvirt-vm' Builds a derivation with everything needed to create a libvirt domain VM.
