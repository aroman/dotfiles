# Granola (granola.ai), which only ships for macOS and Windows, run on Linux.
# Everything Granola lives here and in ./granola/; importing this module is
# the whole integration, and dropping the import removes all of it.
#
#   granola/package.nix       macOS bundle on nixpkgs' Electron (bump notes inside)
#   granola/patch_app.py      the Linux patches to Granola's JS
#   granola/niri.kdl          popup and screen-share window rules
#   granola/noctalia-plugin/  bar widget + panel: next meeting, join link, dismiss
{ lib, username, ... }:
{
  # As pkgs.granola, so `nix build .#nixosConfigurations.<host>.pkgs.granola`
  # builds exactly what the host installs (with its allowUnfree).
  nixpkgs.overlays = [
    (final: _: { granola = final.callPackage ./granola/package.nix { }; })
  ];

  # Remove speaker audio from Granola's microphone track before capture,
  # using the default output's monitor as the echo reference. Monitor mode
  # leaves playback on the real speakers/headset.
  # This is a general-purpose virtual mic, selectable by any app. Granola's
  # wrapper opts in without changing the desktop's default microphone.
  services.pipewire.extraConfig.pipewire."80-echo-cancel" = {
    "context.modules" = [{
      name = "libpipewire-module-echo-cancel";
      args = {
        "library.name" = "aec/libspa-aec-webrtc";
        "monitor.mode" = true;
        "audio.rate" = 48000;
        "capture.props" = {
          "node.name" = "echo_cancel_capture";
          "audio.position" = [ "MONO" ];
        };
        "source.props" = {
          "node.name" = "echo_cancel_source";
          "node.description" = "Microphone (echo cancelled)";
          "audio.position" = [ "MONO" ];
          # Granola opts in through PULSE_SOURCE. Prefer physical mics for
          # the desktop default and this filter's own capture.
          "priority.session" = 0;
        };
        "sink.props" = {
          "node.name" = "echo_cancel_reference";
          "audio.position" = [ "FL" "FR" ];
        };
      };
    }];
  };

  home-manager.users.${username} = { config, pkgs, ... }:
    let
      link = path: config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/Projects/dotfiles/nixos/granola/${path}";
      startupDependencies = [
        "niri-wayland-env-gate.service"
        "xdg-desktop-portal.service"
      ] ++ lib.optional (config.systemd.user.services ? gcr-prompter) "gcr-prompter.service";
    in
    {
      home.packages = [ pkgs.granola ];

      # Keep autostart logs and order startup after the portal and keyring
      # prompt UI. Their readiness does not guarantee storage is unlocked;
      # patch_app.py handles failed or stalled encrypted-storage startup.
      systemd.user.services.granola = {
        Unit = {
          Description = "Granola meeting notes";
          Wants = startupDependencies;
          After = [ "graphical-session.target" ] ++ startupDependencies;
          PartOf = [ "graphical-session.target" ];
        };
        Service = {
          Type = "exec";
          ExecStart = "${pkgs.granola}/bin/granola --start-in-tray";
          Restart = "on-failure";
          # Storage failure needs user attention, not repeated unlock dialogs.
          RestartPreventExitStatus = [ 78 ];
          RestartSec = 3;
        };
        Install.WantedBy = [ "graphical-session.target" ];
      };

      # Sign-in hands the token back via granola://.
      xdg.mimeApps.defaultApplications."x-scheme-handler/granola" = "granola.desktop";

      # config/niri/main.kdl includes this path with optional=true, so hosts
      # without this module simply skip it.
      xdg.configFile."niri-nix/granola.kdl".source = link "niri.kdl";

      # Next meeting in the bar. Granola writes what its macOS menu-bar item
      # would show to $XDG_RUNTIME_DIR/granola/next-meeting.json (patch_app.py);
      # the widget hides when Granola isn't running or nothing is coming up.
      # Linked to the repo like the rcm-delivered plugins, so edits hot-reload.
      xdg.dataFile."noctalia/plugins/granola".source = link "noctalia-plugin";
      programs.noctalia.settings = {
        plugins.enabled = [ "aroman/granola" ];
        widget.granola.type = "aroman/granola:next-meeting";
        bar.main.end = lib.mkBefore [ "granola" ];
      };
    };
}
