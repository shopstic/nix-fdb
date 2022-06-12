{ version ? "7.1.9"
, sha256 ? "sha256-he7NnkE3b3KqAkw/VdabXXeLnk5Ct4E/VE/ZOSf+ntw="
, fetchurl
, stdenv
, lib
}:
stdenv.mkDerivation {
  inherit version;
  pname = "foundationdb";

  src = fetchurl {
    url = "https://bin-cache.shopstic.com/fdb/aarch64-darwin/${version}.tar.gz";
    sha256 = sha256;
  };

  outputs = [ "out" "lib" "bindings" ];

  setSourceRoot = "sourceRoot=`pwd`";

  dontPatchShebangs = true;

  installPhase = ''
    cp -r . $out
    cp -r $out/lib $lib
    cp -r $out/bindings $bindings
  '';

  meta = with lib; {
    description = "Open source, distributed, transactional key-value store";
    homepage = "https://www.foundationdb.org";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" ];
  };
}