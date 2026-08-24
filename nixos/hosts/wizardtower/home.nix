{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home.nix
    # ── herdr headless server ────────────────────────────────────────
    # `default.target`, not `graphical-session.target`: the server must be
    # independent of the niri session so it survives logout and comes up on
    # boot. `loginctl enable-linger` is already set via modules/common.nix.
    #
    # HERDR_CONFIG_PATH is set declaratively rather than inherited from a
    # shell: only the *server* needs it, and unset it silently falls back to
    # herdr's built-in defaults while still reporting `config: ok`. Panes do
    # not need it — fish sources config.fish and conf.d/ for every instance,
    # login or not, so they pick up the full PATH on their own (herdr's
    # shell_mode = "auto" spawns non-login shells on Linux).
    ../../modules/herdr-server.nix
  ];

  home.packages = with pkgs; [
    discord
    slack
  ];
}
