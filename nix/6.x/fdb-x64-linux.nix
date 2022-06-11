{ stdenv
, fetchurl
, runCommandNoCC
}:
stdenv.mkDerivation
rec {
  pname = "foundationdb";
  version = "6.3.22";

  src = fetchurl {
    url = "https://www.foundationdb.org/downloads/${version}/linux/fdb_${version}.tar.gz";
    sha256 = "sha256-FMsH/bfM/HWH1s7eQbGvnEweHLJbXrYi2lSxpxptZ14=";
  };

  fdbLib = fetchurl {
    url = "https://www.foundationdb.org/downloads/${version}/linux/libfdb_c_${version}.so";
    sha256 = "sha256-avdqBZ3YFMsX8GQ+ReHUaZTSYG2Xvnz+C86ZQOpBUaU=";
  };

  installPhase = ''
    mkdir -p $out/bin $out/lib $lib
    find . -type f -not -path "*.sha256" -exec cp {} $out/bin/ \;
    cp ${fdbLib} $out/lib/libfdb_c.so
    cp ${fdbLib} $lib/libfdb_c.so
  '';

  outputs = [ "out" "lib" ];
}
