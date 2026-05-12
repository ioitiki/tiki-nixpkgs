{
  fetchFromGitHub,
  callPackage,
  uv2nix,
  pyproject-nix,
  pyproject-build-systems,
  npm-lockfile-fix,
}:

let
  revision = "99ad2d1372d3b5ff9134e9d8930fed6de4fc7b62";

  src = fetchFromGitHub {
    owner = "NousResearch";
    repo = "hermes-agent";
    rev = revision;
    hash = "sha256-QnUOk0DIBH3IdKnksSlsgqYe6gUpK489Px0Yc6y6f3U=";
  };
in
(callPackage (src + "/nix/hermes-agent.nix") {
  inherit
    uv2nix
    pyproject-nix
    pyproject-build-systems
    npm-lockfile-fix
    ;
  rev = revision;
}).overrideAttrs
  (old: {
    version = "${old.version}-unstable-2026-05-12";

    passthru = (old.passthru or { }) // {
      inherit revision src;
    };
  })
