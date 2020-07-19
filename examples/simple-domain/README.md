# simple domain

This example shows a way to describe a NixOS VM, evaluate its config as a libvirt domain and results in a derivation with a set of scripts to build & start the domain.

## Usage

Build with `nix-build`

Recreate the libvirt domain with `./result/bin/recreate-libvirt-domain--nixos-vm1`

## Main files

### vm1.nix

This is a NixOS module, it defines the configurations that are specific for the VM like it's hostname & the name of the generated libvirt domain.

It also imports more configurations from the file `vm-generic.nix` (see below).

### vm-generic.nix

This is a NixOS module, imported in `vm1.nix`. It defines common configurations like the locale, the timezone or the users and enables ssh.

It enables the ssh service (which is declared & defined in another NixOS module in the official nixpkgs repository).

It makes the VM headless, to avoid installing a huge pire of software for a simple VM.

It makes a single `root` user with password `bla`, adds a nice motd message that will appear when you connect to the VM.

It adds a few packages: `neovim`, `python3`, `curl`.

It disables DHCP for all network interfaces, you should enable it per iterfaces if needed.

NOTE: The files options in `vm1.nix` & `vm-generic.nix` could be merged into a single file, but in general it's a good practice to split common options and specific options so it's easy to define multiple vms for example.

### default.nix

This is a normal Nix file, that builds a full derivation with scripts create a libvirt domain VM from the specification in `vm1.nix`.

The [libvirt tools](../..) are imported and used to evaluate the NixOS configuration
