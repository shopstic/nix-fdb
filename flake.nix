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
    flakeUtils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = import nixpkgs {
          inherit system;
          config = {
            allowBroken = system == "x86_64-darwin";
          };
        };
        fdb = pkgs.callPackage ./fdb.nix {
          darwin = if pkgs.stdenv.isDarwin then pkgs.darwin else null;
        };
      in
      {
        devShell = fdb.shell;
        defaultPackage = fdb.package;
      }
    );
}
