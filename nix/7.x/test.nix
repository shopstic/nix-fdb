{ lib
, stdenv
, fdb
, removeReferencesTo
, autoPatchelfHook
, openjdk11
, gcc11
, glibc
, runCommand
}:
runCommand "fdb-test"
{
  nativeBuildInputs = [
    # autoPatchelfHook
    removeReferencesTo
  ];

  # allowedReferences = [ ];
  # disallowedReferences = [
  #   stdenv.cc
  #   stdenv.cc.cc
  #   gcc11
  # ];
} ''
  mkdir -p $out/lib
  cp -r ${fdb.lib}/libfdb_java.so $out/lib/
  remove-references-to -t ${gcc11.cc} $out/lib/libfdb_java.so
  remove-references-to -t ${glibc.dev} $out/lib/libfdb_java.so
  remove-references-to -t ${openjdk11} $out/lib/libfdb_java.so
''


