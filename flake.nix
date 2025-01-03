{
  description = "Unofficial Microsoft Defender Advanced Threat Protection Nix flake";

  inputs = {
    nixpkgs.url = "nixpkgs";

    flake-utils.url = "github:numtide/flake-utils";
  };

  outputs = { nixpkgs, flake-utils, ... }:
    {
      nixosModules = rec {
        default = mdatp;
        mdatp = import ./nixos;
      };

      overlays = {
        default = import ./overlay.nix;
      };
    }
    // flake-utils.lib.eachSystem [ "x86_64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
        };
      in {
        packages = rec {
          mdatp = pkgs.callPackage ./package.nix { };
          default = mdatp;
        };
      });
}
