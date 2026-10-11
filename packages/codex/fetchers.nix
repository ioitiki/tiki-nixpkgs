# not a stable interface, do not reference outside the codex package but make a copy if you need
#
# Codex compiles rusty_v8 with `v8_enable_sandbox`. denoland/rusty_v8 does not
# publish that variant, so unlike nixpkgs we fetch the sandbox-enabled archive
# and its matching generated binding from Codex's own rusty-v8 releases.
{
  lib,
  stdenv,
  fetchurl,
}:

let
  inherit (stdenv.hostPlatform) system;
  target = stdenv.hostPlatform.rust.rustcTarget;
  releaseBase = version: "https://github.com/openai/codex/releases/download/rusty-v8-v${version}";
  shaFor =
    args:
    args.shas.${system} or (throw "codex: no sandbox-enabled rusty_v8 prebuilt pinned for ${system}");
in
{
  fetchLibrustyV8 =
    args:
    fetchurl {
      name = "librusty_v8-${args.version}";
      url = "${releaseBase args.version}/librusty_v8_ptrcomp_sandbox_release_${target}.a.gz";
      sha256 = shaFor args;
      meta = {
        inherit (args) version;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };

  fetchLibrustyV8SrcBinding =
    args:
    fetchurl {
      name = "src_binding-${args.version}";
      url = "${releaseBase args.version}/src_binding_ptrcomp_sandbox_release_${target}.rs";
      sha256 = shaFor args;
      meta = {
        inherit (args) version;
        sourceProvenance = with lib.sourceTypes; [ binaryNativeCode ];
      };
    };
}
