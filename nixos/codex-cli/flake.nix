{
  description = ''
    codex-cli-nix + the code-mode host binary the upstream flake omits.

    Codex >= 0.143 splits its "code mode" runtime into a SEPARATE release
    binary, `codex-code-mode-host`, shipped as its own GitHub release asset.
    sadjow/codex-cli-nix only fetches the main `codex` binary, so when the
    server enables code mode Codex tries to spawn
    `dirname(current_exe)/codex-code-mode-host` and dies with ENOENT (or, if
    you fake it with a symlink to codex-raw, "exited during handshake" — the
    host is a genuinely different binary, not codex under another name).

    This overlay fetches the matching-version host and installs it next to
    codex-raw, where Codex resolves it. Bump `hostHash` (and re-point the
    input rev) whenever the codex version changes.
  '';

  # Pinned to the rev that builds codex 0.144.1 so the host asset below matches.
  inputs.codex-cli-nix.url =
    "github:sadjow/codex-cli-nix/77438a11367ee33190afe5c6cdf22634eced8e77";

  outputs = { self, codex-cli-nix }:
    let
      system = "x86_64-linux";
      pkgs = codex-cli-nix.inputs.nixpkgs.legacyPackages.${system};
      base = codex-cli-nix.packages.${system}.default;

      # SHA-256 (SRI) of codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz
      # for the matching codex release. Update alongside the input rev.
      hostHash = "sha256-GJrd8L4WqEaVQJMceKDSdnX2TgX2WaZcfVWBODg90l8=";

      codexCodeModeHost = pkgs.fetchurl {
        url = "https://github.com/openai/codex/releases/download/rust-v${base.version}/codex-code-mode-host-x86_64-unknown-linux-musl.tar.gz";
        hash = hostHash;
      };
    in
    let
      fixed = base.overrideAttrs (old: {
        postInstall = (old.postInstall or "") + ''
          tar -xzf ${codexCodeModeHost} -C "$TMPDIR"
          install -Dm555 "$TMPDIR/codex-code-mode-host-x86_64-unknown-linux-musl" \
            "$out/bin/codex-code-mode-host"
        '';
      });
    in
    {
      packages.${system} = {
        default = fixed;
        codex = fixed;
      };
    };
}
