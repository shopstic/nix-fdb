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
, darwin ? null
, version ? "6.3.22"
, sha256 ? "CDoemOctjuU1Z0BiN0J8QbmhZcnXFqdBLcEEO2/XgEw="
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
    # autoPatchelfHook
  ] ++ darwinFrameworks;
in
{
  shell = mkShellNoCC
    {
      NIX_LDFLAGS = ldFlags;
      buildInputs = buildInputs ++ nativeBuildInputs;
    };

  package = stdenv.mkDerivation {
    pname = "foundationdb";
    version = version;

    src = fetchFromGitHub {
      owner = "apple";
      repo = "foundationdb";
      rev = version;
      sha256 = sha256;
    };

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

      substituteInPlace ./fdbmonitor/fdbmonitor.cpp --replace "#ifdef __APPLE__" "''${FDB_MONITOR_PATCH}"
      substituteInPlace ./bindings/c/CMakeLists.txt --replace "if(NOT WIN32)" "if(false)"
    '';

    buildPhase = ''
      ninja -j "$NIX_BUILD_CORES" -v
    '';

    installPhase = ''
      rsync -avrx --exclude={'docker','*.dll','*.exe','*.tar.gz','*-tests.jar'} ./packages/ $out/
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
