{
  description = "FDB";

  inputs = {
    flakeUtils = {
      url = "github:numtide/flake-utils";
      inputs.nixpkgs.follows = "nixpkgs";
    };
  };

  outputs = { self, nixpkgs, flakeUtils }:
    flakeUtils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (system:
      let
        pkgs = nixpkgs.legacyPackages.${system};
        fdb = import ./fdb.nix {
          darwin = if pkgs.stdenv.isDarwin then pkgs.darwin else null;
          inherit (pkgs)
            mkShellNoCC
            fetchFromGitHub
            lib
            stdenv
            gcc10
            cmake
            ninja
            unzip
            openjdk11
            mono
            boost172
            rsync
            python3
            git
            ;
        };
      in
      {
        devShell = fdb.shell;
        defaultPackage = fdb.package;
      }
    );
}
