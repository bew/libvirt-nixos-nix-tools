{ nixpkgs ? import <nixpkgs> {}
}:

let
  networkTools = import ./networkTools.nix { inherit nixpkgs; };
in {
  inherit (networkTools) makeIsolatedNetwork makeIsolatedNetworkIP24;
  inherit (networkTools) makeHostOnlyNetwork makeHostOnlyNetworkIP24;

  evalConfigAsDomain = import ./eval-config-as-domain.nix;
}
