# This is file imported in the final nixos config from the ./vm1.nix file.

{ config, pkgs, ... }:

{
  # Make sure the VM is headless!
  # No need to install a huge pile of software for a simple VM!
  virtualisation.graphics = false;

  # Select internationalisation properties.
  i18n.defaultLocale = "en_US.UTF-8";
  console = {
    font = "Lat2-Terminus16";
    keyMap = "fr";
  };

  # Set your time zone.
  time.timeZone = "Europe/Paris";

  # Enable the OpenSSH daemon.
  services.openssh = {
    enable = true;
    permitRootLogin = "yes";
    # This is insecure, but it's ok for this simple VM and `root` is our only user anyway.
  };

  networking.useDHCP = false; # (configured per interface if needed)

  # List packages installed in system profile. To search, run:
  # $ nix search wget
  environment.systemPackages = [
    pkgs.neovim
    pkgs.python3
    pkgs.curl
  ];

  users = {
    # NOTE: a password is needed to connect to the VM using ssh.
    users.root.password = "bla";
    mutableUsers = false; # No other users are allowed

    motd = ''
      Welcome to ${config.networking.hostName}

      - This machine is managed by NixOS
      - All changes are futile

      OS:      NixOS ${config.system.nixos.release} (${config.system.nixos.codeName})
      Version: ${config.system.nixos.version}
    '';
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It‘s perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  # Before changing this value read the documentation for this option
  # (e.g. man configuration.nix or on https://nixos.org/nixos/options.html).
  system.stateVersion = "20.03"; # Did you read the comment?
}
