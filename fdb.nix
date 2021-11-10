{ lib
, mkShellNoCC
, fetchFromGitHub
, stdenv
, gcc10
, cmake
, ninja
, unzip
, openjdk11
, mono
, boost172
, rsync
, python3
, git
, darwin ? null
, version ? "6.3.22"
}:
let
  darwinFrameworks = lib.optionals (darwin != null) (with darwin.apple_sdk.frameworks; [
    CoreFoundation
    IOKit
  ]);
  lbFlags = lib.concatMapStringsSep " " (f: "-F${f}/Library/Frameworks") darwinFrameworks;
  buildInputs = [ boost172 ];
  nativeBuildInputs = [
    gcc10
    cmake
    ninja
    unzip
    openjdk11
    mono
    rsync
    python3
    git
  ] ++ darwinFrameworks;
in
{
  shell = mkShellNoCC
    {
      NIX_LDFLAGS = lbFlags;
      buildInputs = buildInputs ++ nativeBuildInputs;
    };

  package = stdenv.mkDerivation {
    pname = "foundationdb";
    version = version;

    src = fetchFromGitHub {
      owner = "apple";
      repo = "foundationdb";
      rev = version;
      sha256 = "CDoemOctjuU1Z0BiN0J8QbmhZcnXFqdBLcEEO2/XgEw=";
    };

    NIX_LDFLAGS = lbFlags;
    GIT_EXECUTABLE = git;

    buildInputs = buildInputs;
    nativeBuildInputs = nativeBuildInputs;

    separateDebugInfo = true;
    dontFixCmake = true;

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

      substituteInPlace ./fdbmonitor/fdbmonitor.cpp --replace "#ifdef __APPLE__" "''${FDB_MONITOR_PATCH}"
      substituteInPlace ./bindings/c/CMakeLists.txt --replace "if(NOT WIN32)" "if(false)"
    '';

    buildPhase = ''
      ninja -j "$NIX_BUILD_CORES" -v
    '';

    installPhase = ''
      rsync -avrx --exclude={'docker','*.dll','*.exe','*.tar.gz','*-tests.jar'} ./packages/ $out/
    '';

    dontPatchShebangs = true;

    meta = with lib; {
      description = "Open source, distributed, transactional key-value store";
      homepage = "https://www.foundationdb.org";
      license = licenses.asl20;
      platforms = [ "x86_64-darwin" "x86_64-linux" "aarch64-linux" ];
    };
  };
}
