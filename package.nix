{
  stdenv,
  lib,
  fetchurl,
  dpkg,
  systemd,
  libselinux,
  libcxx,
  minizip-ng,
  curl,
  libseccomp,
  libuuid,
  openssl,
  gcc,
  libcap,
  acl,
  zlib,
  fuse,
  sqlite,
  nixosTests,
}:
let
  libPath = {
    mdatp = lib.makeLibraryPath [
      systemd
      libselinux
      libcxx
      minizip-ng
      curl
      libseccomp
      libuuid
      openssl
      gcc.cc.lib # Specifically for libatomic
      libcap
      acl
      zlib
      fuse
      sqlite
    ];
  };
in
stdenv.mkDerivation rec {
  pname = "mdatp";
  version = "101.24092.0002";

  src = fetchurl {
    url = "https://packages.microsoft.com/debian/12/prod/pool/main/m/${pname}/${pname}_${version}_amd64.deb";
    hash = "sha256-56ScKwpUB6U1jL55eOgn95zvrUn4uXdbj1XJEMfSqMQ=";
  };

  nativeBuildInputs = [ dpkg ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -a opt/microsoft/mdatp/sbin/* $out/bin/
    # mkdir -p $out/lib/security
    # cp -a ./usr/lib/x86_64-linux-gnu/security/pam_intune.so $out/lib/security/
    # cp -a usr/lib/tmpfiles.d $out/lib
    mkdir -p $out/lib/systemd/system
    cp -a opt/microsoft/mdatp/conf/mdatp.service $out/lib/systemd/system/

    # Copy internal libs
    mkdir -p $out/lib
    cp -a opt/microsoft/mdatp/lib/libwdavdaemon_core.so $out/lib
    cp -a opt/microsoft/mdatp/lib/libwdavdaemon_edr_dylib.so $out/lib
    cp -a opt/microsoft/mdatp/lib/libazure-storage-lite.so $out/lib
    cp -a opt/microsoft/mdatp/lib/libcpprest.so.2.10 $out/lib
    # Segfaults with boost183 :(
    cp -a opt/microsoft/mdatp/lib/libboost*.so.* $out/lib

    # Patch binaries
    printf $out/bin/wdavdaemon,$out/bin/wdavdaemonclient | xargs -d ',' patchelf \
      --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
      --set-rpath ${libPath.mdatp}:$out/lib \
      --replace-needed libminizip.so.2.5 libminizip-ng.so

    # Patch libs
    ls -d $out/lib/*.so | xargs patchelf \
      --set-rpath ${libPath.mdatp}:$out/lib \
      --replace-needed libminizip.so.2.5 libminizip-ng.so

    substituteInPlace $out/lib/systemd/system/mdatp.service \
      --replace \
        ExecStart=/opt/microsoft/mdatp/sbin/wdavdaemon \
        ExecStart=$out/bin/wdavdaemon \
      --replace \
        WorkingDirectory=/opt/microsoft/mdatp/sbin \
        WorkingDirectory=$out/bin/ \
      --replace \
        Environment=LD_LIBRARY_PATH=/opt/microsoft/mdatp/lib/ \
        Environment=LD_LIBRARY_PATH=${libPath.mdatp}

    runHook postInstall
  '';

  dontPatchELF = true;

  /*passthru = {
    updateScript = ./update.sh;
    tests = { inherit (nixosTests) intune; };
  };*/

  meta = with lib; {
    description = "Microsoft Defender Advanced Threat Protection for Endpoints";
    homepage = "https://www.microsoft.com/";
    license = licenses.unfree;
    platforms = [ "x86_64-linux" ];
    maintainers = with lib.maintainers; [ epetousis ];
  };
}
