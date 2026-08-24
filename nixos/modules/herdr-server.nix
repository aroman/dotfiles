{ config, pkgs, ... }:

let
  # herdr is installed imperatively via `nix profile` (see modules/common.nix),
  # so there is no store path to reference and the unit goes through the
  # profile symlink — whatever version was last pinned.
  herdr = "${config.home.homeDirectory}/.nix-profile/bin/herdr";

  # herdr has no systemd story of its own: nothing in its docs or packaging
  # mentions units, and the server it spawns is only setsid(2)-detached, so it
  # stays in whichever cgroup started it (herdrdev/herdr#1762 — the proposed
  # upstream fix is to spawn it as a transient `systemd-run --user` unit, which
  # is roughly what this file does by hand). Two consequences we have to absorb:
  #
  #   * a client that finds no server autospawns one, detached, in whatever
  #     scope it ran in — an SSH session, typically;
  #   * a live handoff (`herdr --remote <host> --handoff`, the supported way to
  #     move a running server onto a new binary without killing panes) has the
  #     old server spawn its successor and then exit.
  #
  # Either way something holds ~/.config/herdr/herdr.sock that systemd did not
  # start, and `herdr server` refuses to be the second: it prints "herdr server
  # is already running" and exits 1. Paired with a plain `Restart=`, that is an
  # infinite restart loop — wizardtower sat in one for twelve days and 413,987
  # restarts, and could never have recovered on its own.
  #
  # So don't race for the socket. If someone else owns it, watch and wait; take
  # over only once it is actually free.
  supervise = pkgs.writeShellScript "herdr-supervise" ''
    set -u

    log() { printf 'herdr-supervise: %s\n' "$1"; }

    state=start
    while :; do
      if [ ! -x "${herdr}" ]; then
        # `nix profile remove herdr && nix profile add ...` leaves a window
        # with no binary at all. Wait it out instead of spending restarts on it.
        if [ "$state" != missing ]; then
          log "no herdr binary at ${herdr} — waiting (profile being repinned?)"
          state=missing
        fi
      elif [ "$(${herdr} status server --json 2>/dev/null | ${pkgs.jq}/bin/jq -r '.running')" = true ]; then
        if [ "$state" != foreign ]; then
          log "a server already owns the socket — supervising it rather than starting a second one"
          state=foreign
        fi
      else
        break
      fi
      sleep 10
    done

    log "starting server"
    exec ${herdr} server
  '';

  # systemd runs ExecStop even when the main process exited on its own —
  # "the stop operation is always performed if the service started
  # successfully, even if the processes in the service terminated on their
  # own". A naive `ExecStop=herdr server stop` would therefore fire straight
  # after a handoff and stop the *successor*, killing exactly the panes the
  # handoff preserved.
  #
  # systemd does unset $MAINPID once it knows the main process is gone, which
  # is the discriminator: MAINPID set means we still own the socket and should
  # shut the server down properly; MAINPID unset means our process is already
  # gone and whatever answers now is not ours to stop.
  stopIfOurs = pkgs.writeShellScript "herdr-stop-if-ours" ''
    set -u

    if [ -z "''${MAINPID:-}" ] || ! kill -0 "$MAINPID" 2>/dev/null; then
      echo 'herdr-stop: main process already gone — leaving the current server alone'
      exit 0
    fi

    exec ${herdr} server stop
  '';
in
{
  # Hosts that are attached to remotely and never drive a local TUI run the
  # server as a unit rather than waiting for a first interactive `herdr` to
  # spawn it. Imported per-host, not from modules/home.nix: moonbinder is used
  # interactively and should keep the default client-spawns-server behaviour.
  systemd.user.services.herdr = {
    Unit = {
      Description = "herdr headless server";
      # Agent panes shell out to git, ssh and network tools on startup.
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
      # Backstop for a server that dies on startup for a reason waiting cannot
      # fix (unreadable config, corrupt session.json). Fail visibly instead of
      # spinning; the wait loop above already covers the transient cases.
      StartLimitIntervalSec = 60;
      StartLimitBurst = 5;
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
      # by whether it last started before or after a graphical login. (A no-op
      # on the cloud hosts, which never set either.)
      UnsetEnvironment = [ "WAYLAND_DISPLAY" "DISPLAY" ];
      ExecStart = "${supervise}";
      # A deliberate `systemctl restart` is therefore the "take the socket
      # back" gesture: it stops whichever server holds it and starts a fresh
      # one on the current binary, at the cost of the panes.
      ExecStop = "${stopIfOurs}";
      # Kill the supervisor only. Default control-group killing would reap a
      # handed-off successor too — it is spawned from inside this unit's
      # cgroup — which is the whole thing we are avoiding.
      KillMode = "process";
      # `always`, not `on-failure`: a handoff leaves the old server exiting 0,
      # and the unit should still come back around to supervise its successor.
      Restart = "always";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
