{ lib
, mkShellNoCC
, fetchFromGitHub
, stdenv
, gcc11
, cmake
, ninja
, unzip
, openjdk11
, mono
, boost178
, rsync
, python3
, git
, tree
, darwin ? null
, boringssl
, version ? "6.3.24"
, sha256 ? "sha256-GMX0dFYnesT/R5lm3OtK1SyS7Jnd81duVJ5NmWcfHsU="
}:
let
  darwinFrameworks = lib.optionals (darwin != null) (with darwin.apple_sdk.frameworks; [
    CoreFoundation
    IOKit
  ]);
  ldFlags = lib.concatMapStringsSep " " (f: "-F${f}/Library/Frameworks") darwinFrameworks;
  buildInputs = [ boost178 ];
  nativeBuildInputs = [
    gcc11
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
    # autoPatchelfHook
  ] ++ darwinFrameworks;

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

  NIX_LDFLAGS = ldFlags;
  GIT_EXECUTABLE = git;

  buildInputs = buildInputs;
  nativeBuildInputs = nativeBuildInputs;

  separateDebugInfo = true;
  # dontFixCmake = true;

  cmakeFlags = [
    "-G"
    "Ninja"
    # "-DBUILD_DOCUMENTATION=OFF"
    # "-DFDB_RELEASE=ON"
    "-DSSD_ROCKSDB_EXPERIMENTAL=OFF"
    "-DCMAKE_BUILD_TYPE=Release"
  ];

  patchPhase = ''
    FDB_MONITOR_PATCH=$(cat <<EOF
    #ifdef __APPLE__
    #ifndef PATH_MAX
    #define PATH_MAX 4096
    #endif
    EOF
    )

    substituteInPlace ./bindings/c/CMakeLists.txt --replace \
      'fdb_c.map,-z,nodelete")' \
      'fdb_c.map,-z,nodelete,-z,noexecstack")'

    substituteInPlace ./fdbmonitor/fdbmonitor.cpp --replace "#ifdef __APPLE__" "''${FDB_MONITOR_PATCH}"

    substituteInPlace ./bindings/c/CMakeLists.txt --replace "if(NOT WIN32)" "if(false)"
  '';

  buildPhase = ''
    ninja -j "$NIX_BUILD_CORES" -v
  '';

  installPhase = ''
    rsync -avrx --exclude={'docker','*.dll','*.exe','*.tar.gz','*-tests.jar'} ./packages/ $out/
    mkdir -p $out/bindings/foundationdb
    cp ./bindings/c/foundationdb/fdb_c_options.g.h $out/bindings/foundationdb
    cp ${src}/bindings/c/foundationdb/fdb_c.h $out/bindings/foundationdb
    cp -r $out/lib $lib
    cp -r $out/bindings $bindings
  '';

  dontPatchShebangs = true;
  # autoPatchelfIgnoreMissingDeps = true;

  outputs = [ "out" "lib" "bindings" ];

  meta = with lib; {
    priority = 10;
    description = "Open source, distributed, transactional key-value store";
    homepage = "https://www.foundationdb.org";
    license = licenses.asl20;
    platforms = [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
  };
}
