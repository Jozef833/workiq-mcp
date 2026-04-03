{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,

  # workiq binary deps
  glibc,
  gcc-unwrapped,
  icu,
  openssl_3,
  zlib,

  # libmsalruntime.so deps
  curl,
  dbus,
  util-linux,
  gtk3,
  webkitgtk_4_1,
  libsecret,
  libsoup_3,
  glib,
  pango,
  harfbuzz,
  atk,
  cairo,
  gdk-pixbuf,
  libx11,
  p11-kit,
}:
let
  version = "0.4.0";

  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "osx-x64";
    "aarch64-darwin" = "osx-arm64";
  };

  platformDir = platformMap.${stdenv.hostPlatform.system} or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "workiq";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@microsoft/workiq/-/workiq-${version}.tgz";
    hash = "sha256-sTG5YKZSmE57YlaJ6xRaBAewi9qJmsF48lsOxCJZXyA=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    # workiq binary deps
    glibc
    gcc-unwrapped.lib
    icu
    openssl_3
    zlib

    # libmsalruntime.so deps
    curl
    dbus
    util-linux.lib
    gtk3
    webkitgtk_4_1
    libsecret
    libsoup_3
    glib
    pango
    harfbuzz
    atk
    cairo
    gdk-pixbuf
    libx11
    p11-kit
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec $out/lib

    cp package/bin/${platformDir}/workiq $out/libexec/workiq
    chmod +x $out/libexec/workiq

    # libmsalruntime.so must be discoverable via LD_LIBRARY_PATH
    if [ -f package/bin/${platformDir}/libmsalruntime.so ]; then
      cp package/bin/${platformDir}/libmsalruntime.so $out/lib/
    fi
    if [ -f package/bin/${platformDir}/libmsalruntime.dylib ]; then
      cp package/bin/${platformDir}/libmsalruntime.dylib $out/lib/
    fi

    # Manual wrapper to avoid makeWrapper renaming the binary
    # (.workiq-wrapped breaks .NET's System.CommandLine root command parser)
    cat > $out/bin/workiq <<WRAPPER
    #!${stdenv.shell}
    export LD_LIBRARY_PATH="$out/lib:${lib.makeLibraryPath [ icu openssl_3 zlib ]}\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    exec "$out/libexec/workiq" "\$@"
    WRAPPER
    chmod +x $out/bin/workiq

    runHook postInstall
  '';

  # .NET self-contained binaries are corrupted by strip
  dontStrip = true;

  meta = {
    description = "MCP server and CLI for Microsoft 365 via Work IQ";
    homepage = "https://github.com/microsoft/work-iq";
    license = lib.licenses.unfree;
    mainProgram = "workiq";
    platforms = lib.attrNames platformMap;
  };
}
