{ lib
, fetchFromGitHub
, stdenv
, gcc11
, clang
, cmake
, ninja
, unzip
, openjdk11
, mono
, rsync
, python3
, git
, tree
, boringssl
, cacert
, lz4
, jemalloc
, autoPatchelfHook
, version ? "7.2.7"
, sha256 ? "sha256-a2Ep7Kl35D3SzKRf4MBpVzgKyNo+WWRN8ztGN4dPD+s="
}:
let
  src = fetchFromGitHub {
    owner = "apple";
    repo = "foundationdb";
    rev = version;
    inherit sha256;
  };
  patchBoostUrl = ''
    substituteInPlace ./cmake/CompileBoost.cmake --replace "https://boostorg.jfrog.io/artifactory/main/release/1.78.0/source/" "https://bin-cache.shopstic.com/fdb-deps/"
  '';
  patchAvxOff = lib.optionalString (!stdenv.isx86_64) ''
    substituteInPlace cmake/ConfigureCompiler.cmake --replace "USE_AVX ON" "USE_AVX OFF"
  '';
in
stdenv.mkDerivation {
  pname = "foundationdb";

  inherit src version;

  nativeBuildInputs = [
    cmake
    ninja
    unzip
    openjdk11
    mono
    rsync
    python3
    git
    tree
    boringssl
    cacert
    lz4.out
    lz4.dev
    jemalloc
    gcc11
    autoPatchelfHook
  ];

  GIT_EXECUTABLE = git;

  __noChroot = true;

  cmakeFlags = [
    "-G"
    "Ninja"
    "-DBUILD_DOCUMENTATION=OFF"
    "-DSSD_ROCKSDB_EXPERIMENTAL=ON"
  ];

  patchPhase = builtins.concatStringsSep "\n" [ patchBoostUrl patchAvxOff ];

  buildPhase = ''
    ninja -j "$NIX_BUILD_CORES" -v
  '';

  installPhase = ''
    rsync -avrx --exclude={'docker','*.dll','*.exe','*.tar.gz','*-tests.jar'} ./packages/ $out/
    mkdir -p $out/bindings/foundationdb
    cp ./bindings/c/foundationdb/fdb_c_options.g.h $out/bindings/foundationdb
    cp ${src}/bindings/c/foundationdb/*.h $out/bindings/foundationdb

    mv $out/lib $lib
    mv $out/bindings $bindings

    find $lib -type f -name "*.so" -exec patchelf --shrink-rpath --allowed-rpath-prefixes "${builtins.storeDir}" {} \;
  '';

  dontPatchShebangs = true;

  outputs = [ "out" "lib" "bindings" ];

  meta = with lib; {
    description = "Open source, distributed, transactional key-value store";
    homepage = "https://www.foundationdb.org";
    license = licenses.asl20;
    platforms = [ "x86_64-linux" "aarch64-linux" ];
  };
}

