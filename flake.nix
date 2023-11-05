{
  description = "FDB";

  inputs = {
    nixpkgs.url = "github:nixos/nixpkgs/nixos-23.05";
    flakeUtils.url = "github:numtide/flake-utils";
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
          pkgs.lib.optionalAttrs (system != "aarch64-darwin") {
            fdb_6 = pkgs.callPackage ./nix/6.x/all.nix {
              darwin = if pkgs.stdenv.isDarwin then pkgs.darwin else null;
            };
          };
        fdb_7_pkgs =
          pkgs.lib.optionalAttrs (system != "x86_64-darwin")
            (
              let
                fdb_7_pkg =
                  if (system == "aarch64-darwin") then
                    (
                      pkgs.callPackage ./nix/7.x/aarch64-darwin.nix { }
                    )
                  else
                    (
                      pkgs.callPackage ./nix/7.x/linux.nix {
                        lz4 = pkgs.lz4.overrideAttrs (oldAttrs: {
                          makeFlags = [
                            "PREFIX=$(out)"
                            "INCLUDEDIR=$(dev)/include"
                            "BUILD_STATIC=yes"
                            "BUILD_SHARED=yes"
                            "WINDRES:=${pkgs.stdenv.cc.bintools.targetPrefix}windres"
                          ];
                        });
                      }
                    );
              in
              {
                fdb_7 = fdb_7_pkg // {
                  all = pkgs.linkFarm "${fdb_7_pkg.name}-all" [
                    {
                      name = "out";
                      path = fdb_7_pkg;
                    }
                    {
                      name = "lib";
                      path = fdb_7_pkg.lib;
                    }
                    {
                      name = "bindings";
                      path = fdb_7_pkg.bindings;
                    }
                  ];
                };
              }
            );
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
