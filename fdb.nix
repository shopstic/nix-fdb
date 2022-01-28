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
, boost172
, rsync
, python3
, git
, tree
, darwin ? null
, boringssl
, version ? "6.3.23"
, sha256 ? "sha256-H2plhQoA6+5cYewlS7ZosNu5a0+Ec5Y/Tw8uRLUoq80="
}:
let
  darwinFrameworks = lib.optionals (darwin != null) (with darwin.apple_sdk.frameworks; [
    CoreFoundation
    IOKit
  ]);
  ldFlags = lib.concatMapStringsSep " " (f: "-F${f}/Library/Frameworks") darwinFrameworks;
  buildInputs = [ boost172 ];
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
in
rec {
  shell = mkShellNoCC
    {
      NIX_LDFLAGS = ldFlags;
      buildInputs = buildInputs ++ nativeBuildInputs;
    };

  src = fetchFromGitHub {
    owner = "apple";
    repo = "foundationdb";
    rev = version;
    inherit sha256;
  };

  package = stdenv.mkDerivation {
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
      mkdir $out/bindings
      cp ./bindings/c/foundationdb/fdb_c_options.g.h $out/bindings/
      cp ${src}/bindings/c/foundationdb/fdb_c.h $out/bindings/
      cp -r $out/lib $lib
    '';

    dontPatchShebangs = true;
    # autoPatchelfIgnoreMissingDeps = true;

    outputs = [ "out" "lib" ];

    meta = with lib; {
      description = "Open source, distributed, transactional key-value store";
      homepage = "https://www.foundationdb.org";
      license = licenses.asl20;
      platforms = [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    };
  };
}
