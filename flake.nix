{
  description = "FDB";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/22.05";
    flakeUtils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flakeUtils }:
    flakeUtils.lib.eachSystem [ "aarch64-darwin" "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowBroken = system == "x86_64-darwin";
          };
        };
        fdb_6_pkgs =
          if system != "aarch64-darwin" then {
            fdb_6 = pkgs.callPackage ./nix/6.x/all.nix {
              darwin = if pkgs.stdenv.isDarwin then pkgs.darwin else null;
            };
          } else { };
        fdb_7_pkgs =
          if system == "aarch64-darwin" then {
            fdb_7 = pkgs.callPackage ./nix/7.x/aarch64-darwin.nix { };
          }
          else if pkgs.stdenv.isLinux then {
            fdb_7 = pkgs.callPackage ./nix/7.x/linux.nix {
              lz4 = pkgs.lz4.overrideAttrs (oldAttrs: {
                makeFlags = [
                  "PREFIX=$(out)"
                  "INCLUDEDIR=$(dev)/include"
                  "BUILD_STATIC=yes"
                  "BUILD_SHARED=yes"
                  "WINDRES:=${pkgs.stdenv.cc.bintools.targetPrefix}windres"
                ];
              });
            };
          }
          else { };
      in
      rec {
        devShell = pkgs.mkShellNoCC {
          buildInputs = builtins.attrValues {
            inherit (pkgs)
              lz4
              ;
          };
        };
        packages = fdb_6_pkgs // fdb_7_pkgs;
        defaultPackage = pkgs.buildEnv {
          name = "fdb";
          paths = builtins.attrValues packages;
        };
      }
    );
}
