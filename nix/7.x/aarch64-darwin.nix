{ fetchurl
, runCommand
, lib
, xar
, gzip
, unzip
, cpio
}:
let
  version = "7.1.53";
  installer = fetchurl {
    name = "foundationdb-installer-${version}";
    url = "https://github.com/apple/foundationdb/releases/download/${version}/FoundationDB-${version}_arm64.pkg";
    sha256 = "sha256-zWsi6KFnAOkypCF6gO9nlYcnFItqEgR44pSrUmYDjUc=";
  };
  jar = fetchurl {
    name = "foundationdb-jar-${version}";
    url = "https://repo1.maven.org/maven2/org/foundationdb/fdb-java/${version}/fdb-java-${version}.jar";
    sha256 = "sha256-9bO6EdWa7IwB4Ha/du7fJ079HouFFFGP1tmFZ1WzBVk=";
  };
in
runCommand "foundationdb-${version}"
{
  nativeBuildInputs = [ xar gzip unzip cpio ];
  outputs = [ "out" "lib" "bindings" ];
  meta = with lib; {
    description = "Open source, distributed, transactional key-value store";
    homepage = "https://www.foundationdb.org";
    license = licenses.asl20;
    platforms = [ "aarch64-darwin" ];
  };
} ''
  xar -xf "${installer}"
  (cd FoundationDB-clients.pkg && cat Payload | gunzip -dc | cpio -i)
  (cd FoundationDB-server.pkg && cat Payload | gunzip -dc | cpio -i)

  mkdir -p $out/bin $lib $bindings
  mv ./FoundationDB-clients.pkg/usr/local/bin/fdbcli $out/bin/
  mv ./FoundationDB-clients.pkg/usr/local/foundationdb/backup_agent/backup_agent $out/bin/
  backup_bins=(dr_agent fdbbackup fdbdr fdbrestore)
  (cd $out/bin && for bin in "''${backup_bins[@]}"; do ln -s backup_agent "$bin"; done)
  mv ./FoundationDB-clients.pkg/usr/local/include/foundationdb $bindings/foundationdb
  mv ./FoundationDB-clients.pkg/usr/local/lib/* $lib/
  mv ./FoundationDB-server.pkg/usr/local/libexec/* $out/bin/

  unzip "${jar}"
  mv ./lib/osx/aarch64/libfdb_java.jnilib $lib/
''
