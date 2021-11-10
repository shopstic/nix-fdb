{
  description = "FDB";

  inputs.flake-utils.url = "github:numtide/flake-utils";

  outputs = { self, nixpkgs, flake-utils }:
    flake-utils.lib.eachSystem [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ] (system:
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
