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
, darwin
, version ? "7.1.20"
, sha256 ? "sha256-l4SLnnFHFGF4GRilyv43IeE3NlYR6adAN2AUNY/mdMM="
}:
let
  src = fetchFromGitHub {
    owner = "apple";
    repo = "foundationdb";
    rev = version;
    inherit sha256;
  };
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
  ] ++ (if stdenv.isDarwin then [
    clang
    darwin.apple_sdk.frameworks.CoreFoundation
    darwin.apple_sdk.frameworks.IOKit
  ] else [
    jemalloc
    gcc11
  ]);

  GIT_EXECUTABLE = git;

  separateDebugInfo = true;

  __noChroot = true;

  cmakeFlags = [
    "-G"
    "Ninja"
    "-DBUILD_DOCUMENTATION=OFF"
    "-DSSD_ROCKSDB_EXPERIMENTAL=ON"
  ];

  patchPhase =
    if stdenv.isDarwin then ''
      substituteInPlace ./cmake/CompileBoost.cmake --replace "/usr/bin/clang++" "${clang}/bin/clang++"
    ''
    # https://github.com/apple/foundationdb/pull/7319/files
    else ''
      WriteOnlySet_PATCH=$(cat <<EOF
      #include <random>
      #include <thread>
      EOF
      )

      substituteInPlace ./flow/WriteOnlySet.actor.cpp --replace "#include <random>" "''${WriteOnlySet_PATCH}"

      substituteInPlace ./fdbbackup/FileDecoder.actor.cpp --replace \
        'self->lfd = open(self->file.fileName.c_str(), O_WRONLY | O_CREAT | O_TRUNC);' \
        'self->lfd = open(self->file.fileName.c_str(), O_WRONLY | O_CREAT | O_TRUNC, 0600);'

      substituteInPlace ./bindings/c/test/unit/third_party/CMakeLists.txt --replace "8424be522357e68d8c6178375546bb0cf9d5f6b3 # v2.4.1" "7b9885133108ae301ddd16e2651320f54cafeba7 # v2.4.8"
    '';

  buildPhase = ''
    ninja -j "$NIX_BUILD_CORES" -v
  '';

  installPhase = ''
    rsync -avrx --exclude={'docker','*.dll','*.exe','*.tar.gz','*-tests.jar'} ./packages/ $out/
    mkdir -p $out/bindings/foundationdb
    cp ./bindings/c/foundationdb/fdb_c_options.g.h $out/bindings/foundationdb
    cp ${src}/bindings/c/foundationdb/*.h $out/bindings/foundationdb
    cp -r $out/lib $lib
    cp -r $out/bindings $bindings
  '';

  dontPatchShebangs = true;

  outputs = [ "out" "lib" "bindings" ];

  meta = with lib; {
    description = "Open source, distributed, transactional key-value store";
    homepage = "https://www.foundationdb.org";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" "x86_64-linux" "aarch64-linux" ];
  };
}

