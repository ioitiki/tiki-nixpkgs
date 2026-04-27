{
  lib,
  stdenv,
  fetchurl,
  autoPatchelfHook,
}:

stdenv.mkDerivation rec {
  pname = "openshell";
  version = "0.0.11";

  src = fetchurl {
    url = "https://github.com/NVIDIA/OpenShell/releases/download/v${version}/openshell-x86_64-unknown-linux-musl.tar.gz";
    hash = "sha256-kPM4sOHT96WADtwqI+w9LK5EkhOebFFePH20dQXbTNs=";
  };

  sourceRoot = ".";

  nativeBuildInputs = [ autoPatchelfHook ];

  # musl-linked static binary — no runtime deps needed
  dontAutoPatchelf = true;

  installPhase = ''
    install -Dm755 openshell $out/bin/openshell
  '';

  meta = {
    description = "NVIDIA OpenShell - gateway and cluster shell tool";
    homepage = "https://github.com/NVIDIA/OpenShell";
    license = lib.licenses.asl20;
    platforms = [ "x86_64-linux" ];
    mainProgram = "openshell";
  };
}
