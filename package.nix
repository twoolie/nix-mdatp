{
  stdenv,
  lib,
  fetchurl,
  makeWrapper,
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
  gzip,
  fuse,
  sqlite,
  coreutils,
  gnugrep,
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
  version = "101.25012.0000";
  src = fetchurl {
    url = "https://packages.microsoft.com/debian/12/prod/pool/main/m/${pname}/${pname}_${version}_amd64.deb";
    hash = "sha256-EBnfz4z1t4jwGPKZIKTK1TFacV3UA3BAD1lS+ixs2TE=";
  };

  nativeBuildInputs = [ dpkg makeWrapper ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin
    cp -a opt/microsoft/mdatp/sbin/* $out/bin/
    # mkdir -p $out/lib/security
    # cp -a ./usr/lib/x86_64-linux-gnu/security/pam_intune.so $out/lib/security/
    # cp -a usr/lib/tmpfiles.d $out/lib
    mkdir -p $out/lib/systemd/system
    cp -a opt/microsoft/mdatp/conf/mdatp.service $out/lib/systemd/system/
    cat > $out/lib/systemd/system/mdatp-prestart.service << EOF
    [Unit]
    Description=Microsoft Defender Prestart
    NeededBy=mdatp.service

    [Service]
    Type=oneshot
    ExecStart=/bin/sh -c "mkdir -p /boot && ${gzip}/bin/zcat > /boot/config-$$(${coreutils}/bin/uname -r)"
    EOF

    # Copy internal libs
    mkdir -p $out/lib
    cp -a opt/microsoft/mdatp/lib/lib*.so.* $out/lib

    # Patch binaries
    printf $out/bin/wdavdaemon,$out/bin/wdavdaemonclient | xargs -d ',' patchelf \
      --set-interpreter $(cat $NIX_CC/nix-support/dynamic-linker) \
      --set-rpath ${libPath.mdatp}:$out/lib \
      --replace-needed libminizip.so.2.5 libminizip-ng.so

    wrapProgram $out/bin/wdavdaemon \
      --prefix PATH : ${lib.makeBinPath [ coreutils gnugrep ]}

    # Patch libs
    ls -d $out/lib/*.so | xargs patchelf \
      --set-rpath ${libPath.mdatp}:$out/lib \
      --replace-needed libminizip.so.2.5 libminizip-ng.so

    substituteInPlace $out/lib/systemd/system/mdatp.service \
      --replace /opt/microsoft/mdatp/sbin $out/bin \
      --replace /opt/microsoft/mdatp/lib ${libPath.mdatp}

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
