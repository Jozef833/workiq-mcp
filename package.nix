{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
  glibc,
  gcc-unwrapped,
  icu,
  openssl,
  zlib,
}:
let
  version = "0.2.8";

  platformMap = {
    "x86_64-linux" = "linux-x64";
    "aarch64-linux" = "linux-arm64";
    "x86_64-darwin" = "osx-x64";
    "aarch64-darwin" = "osx-arm64";
  };

  platformDir =
    platformMap.${stdenv.hostPlatform.system}
      or (throw "Unsupported platform: ${stdenv.hostPlatform.system}");
in
stdenv.mkDerivation {
  pname = "workiq";
  inherit version;

  src = fetchurl {
    url = "https://registry.npmjs.org/@microsoft/workiq/-/workiq-${version}.tgz";
    hash = "sha256-K8/Ve05srYahyTFpemVaxajK1cJw5v9GGpFjDdWGJPc=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [
    autoPatchelfHook
  ];

  buildInputs = [
    glibc
    gcc-unwrapped.lib
    icu
    openssl
    zlib
  ];

  installPhase = ''
    runHook preInstall

    mkdir -p $out/bin $out/libexec

    cp package/bin/${platformDir}/workiq $out/libexec/workiq
    chmod +x $out/libexec/workiq

    # Manual wrapper to avoid makeWrapper renaming the binary
    # (.workiq-wrapped breaks .NET's System.CommandLine root command parser)
    cat > $out/bin/workiq <<WRAPPER
    #!${stdenv.shell}
    export LD_LIBRARY_PATH="${
      lib.makeLibraryPath [
        icu
        openssl
        zlib
      ]
    }\''${LD_LIBRARY_PATH:+:\$LD_LIBRARY_PATH}"
    exec "$out/libexec/workiq" "\$@"
    WRAPPER
    chmod +x $out/bin/workiq

    runHook postInstall
  '';

  # .NET self-contained binaries embed an assembly bundle that strip corrupts
  dontStrip = true;

  meta = {
    description = "MCP server and CLI for Microsoft 365 via Work IQ";
    homepage = "https://github.com/microsoft/work-iq";
    license = lib.licenses.unfree;
    mainProgram = "workiq";
    platforms = lib.attrNames platformMap;
  };
}
