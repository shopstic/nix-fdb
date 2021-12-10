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
