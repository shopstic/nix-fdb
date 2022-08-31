{
  description = "FDB";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-22.05";
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
            packageOverrides = pkgs: {
              mono =
                if system == "aarch64-darwin" then
                  pkgs.mono.overrideAttrs
                    (attrs: rec {
                      version = "6.12.0.182";
                      sha256 = "sha256-VzZqarTztezxEdSFSAMWFbOhANuHxnn8AG6Mik79lCQ=";
                      src = pkgs.fetchurl {
                        inherit sha256;
                        url = "https://download.mono-project.com/sources/mono/${attrs.pname}-${version}.tar.xz";
                      };
                      meta = attrs.meta // {
                        broken = false;
                      };
                    })
                else
                  pkgs.mono;
            };
          };
        };
        fdb_6_pkgs =
          if system != "aarch64-darwin" then {
            fdb_6 = pkgs.callPackage ./nix/6.x/all.nix {
              darwin = if pkgs.stdenv.isDarwin then pkgs.darwin else null;
            };
          } else { };
        fdb_7_pkgs =
          if system != "x86_64-darwin" then
            let
              fdb_7_pkg = pkgs.callPackage ./nix/7.x/all.nix {
                lz4 = pkgs.lz4.overrideAttrs (oldAttrs: {
                  makeFlags = [
                    "PREFIX=$(out)"
                    "INCLUDEDIR=$(dev)/include"
                    "BUILD_STATIC=yes"
                    "BUILD_SHARED=yes"
                    "WINDRES:=${pkgs.stdenv.cc.bintools.targetPrefix}windres"
                  ];
                });
              }; in
            {
              fdb_7 = fdb_7_pkg // {
                toCache = pkgs.buildEnv {
                  name = "fdb-7-to-cache";
                  paths = [ fdb_7_pkg fdb_7_pkg.lib fdb_7_pkg.bindings ];
                };
              };
            } else { };
        # if system == "aarch64-darwin" then {
        #   # fdb_7 = pkgs.callPackage ./nix/7.x/aarch64-darwin.nix { };
        #   fdb_7 = pkgs.callPackage ./nix/7.x/darwin.nix { };
        # }
        # else if pkgs.stdenv.isLinux then {
        #   fdb_7 = pkgs.callPackage ./nix/7.x/linux.nix {
        #     lz4 = pkgs.lz4.overrideAttrs (oldAttrs: {
        #       makeFlags = [
        #         "PREFIX=$(out)"
        #         "INCLUDEDIR=$(dev)/include"
        #         "BUILD_STATIC=yes"
        #         "BUILD_SHARED=yes"
        #         "WINDRES:=${pkgs.stdenv.cc.bintools.targetPrefix}windres"
        #       ];
        #     });
        #   };
        # }
        # else { };
        vscodeSettings = pkgs.writeTextFile {
          name = "vscode-settings.json";
          text = builtins.toJSON {
            "nix.enableLanguageServer" = true;
            "nix.formatterPath" = pkgs.nixpkgs-fmt + "/bin/nixpkgs-fmt";
            "nix.serverPath" = pkgs.rnix-lsp + "/bin/rnix-lsp";
          };
        };
      in
      rec {
        devShell = pkgs.mkShellNoCC {
          shellHook = ''
            mkdir -p ./.vscode
            cat ${vscodeSettings} | jq . > ./.vscode/settings.json
          '';
          buildInputs = builtins.attrValues {
            inherit (pkgs)
              jq
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
