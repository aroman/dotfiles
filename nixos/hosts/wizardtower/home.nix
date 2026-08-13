{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home.nix
  ];

  home.packages = with pkgs; [
    discord
    slack
  ];

  # ── herdr headless server ────────────────────────────────────────
  # This host is attached to remotely and never drives a local TUI, so run
  # the server as a unit rather than waiting for a first interactive
  # `herdr` to spawn it. Only here — moonbinder is used interactively and
  # should keep the default client-spawns-server behaviour.
  #
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
  #
  # ExecStart is an absolute ~/.nix-profile path because herdr is installed
  # imperatively via `nix profile` (see modules/common.nix) and so has no
  # store path to reference.
  systemd.user.services.herdr = {
    Unit = {
      Description = "herdr headless server";
      # Agent panes shell out to git, ssh and network tools on startup.
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "HERDR_CONFIG_PATH=${config.home.homeDirectory}/Projects/dotfiles/config/herdr/config.toml"
      ];
      # The xdg-open shim (modules/home.nix) treats "a display is set" as "the
      # user is sitting at this machine" and opens locally instead of over the
      # bridge to the Mac. That holds for this unit at boot, which is before
      # niri exists — but niri imports WAYLAND_DISPLAY and DISPLAY into the
      # user manager's environment, so any *restart* after login would inherit
      # them and silently start opening links on the tower's own monitor, exit
      # 0, with nobody in front of it. Same unit, opposite behaviour, decided
      # by whether it last started before or after a graphical login.
      UnsetEnvironment = [ "WAYLAND_DISPLAY" "DISPLAY" ];
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/herdr server";
      # Graceful shutdown persists session.json; SIGTERM remains the
      # fallback if the API socket is already gone.
      ExecStop = "${config.home.homeDirectory}/.nix-profile/bin/herdr server stop";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
