# libvirt-nixos-nix-tools

This repository contains a set of Nix tools to create lightweight NixOS VMs managed by libvirt in addition to help creating virtual networks on libvirt and attach the VMs to them.


## What are lightweight NixOS VMs

Disclaimer: I did not invent anything, this is the default behavior of virtual machines built with the command `nixos-rebuild build-vm` in a NixOS system.
The innovation is that those VMs can now be managed by libvirt and be easily attached to virtual networks created with libvirt.

It's basically a full VM with a ridiculously small disk, 10 MB can be enough for some usecases!
This is only possible because the directory hirarchy of the OS with NixOS is immutable and can be shared with the host system.

Basically all files created and managed by Nix are stored in `/nix/store`, including the entire system hierarchy you build when instantiating a NixOS derivation. Now if you share the `/nix/store` between the host and possibly multiple VMs and only store the files necessary for runtime, you get a lightweight VM that uses almost no storage space even if you create 10 of them! (it will use processing power though ^^)


## Security consideration

Note that the VM has a **read-only access** to the whole `/nix/store` of the host system, it is no isolated to its own OS hierarchy.
:warning: An evil user in the VM could potentially run any programs or open any file from the store if he knows where to look or use some smart globing.

These kind of lightweight VMs should not be used for any sensitive work.


## Usage

First clone this repository in some location like `/path/to/libvirt-nixos-nix-tools`, then import the tools like any other Nix file using either the directory/file path or a global path using a custom `NIX_PATH`:

```nix
let
  libvirtTools = import /path/to/libvirt-nixos-nix-tools;

in your-expression # Now you can use the functions in `libvirtTools`
```

You can find an example of usage with documentation in the [`examples/`](examples) directory.

Almost all functions are documented where they are defined, check the source code for all the details, it's all pretty straight forward!


---

## Missing

- configurable emulator path for the VM (easy to add)
- refactor scripts to re-create a domain/network in libvirt
- (maybe?) get rid of `<nixpkgs/nixos/modules/virtualisation/qemu-vm.nix>` dependency and implement everything I need myself (but byebye compatibility..)
- many other things... open an issue if you want to see something you need!
