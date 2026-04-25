{ config, pkgs, lib, inputs, ... }:

let
  # Patch voxtype to fix duplicate transcription notifications.
  # Both the daemon and each output driver send notify-send on transcription;
  # this removes the per-driver call.
  voxtypePatched = let
    unwrapped = inputs.voxtype.packages.x86_64-linux.voxtype-vulkan-unwrapped.overrideAttrs (prev: {
      patches = (prev.patches or []) ++ [
        ../../patches/voxtype-fix-duplicate-notification.patch
        ../../patches/voxtype-paste-dotool-fallback.patch
      ];
    });
    runtimeDeps = with pkgs; [ dotool wtype wl-clipboard libnotify ];
  in pkgs.symlinkJoin {
    name = "${unwrapped.pname}-wrapped-${unwrapped.version}";
    paths = [ unwrapped ];
    buildInputs = [ pkgs.makeWrapper ];
    postBuild = ''
      wrapProgram $out/bin/voxtype \
        --prefix PATH : ${pkgs.lib.makeBinPath runtimeDeps}
    '';
    inherit (unwrapped) meta;
  };
in
{
  imports = [
    ../../modules/home.nix
    inputs.voxtype.homeManagerModules.default
  ];

  home.sessionVariables.JAVA_HOME = "${pkgs.jdk17}";

  home.packages = with pkgs; [
    jdk17
    brightnessctl
    websocat     # WebSocket CLI — used by figma-open to navigate via CDP
    figma-agent  # serves local fonts to Figma web (needs Windows user-agent)
    vesktop
    slack
  ];

  # ── Figma ──────────────────────────────────────────────────────

  # Figma via Chrome app mode instead of figma-linux (Electron).
  # Chrome --app is noticeably faster on Wayland/niri.
  # figma-open handles both launching and URL deep-linking via CDP.
  xdg.desktopEntries.figma = {
    name = "Figma";
    comment = "Figma (Chrome app mode)";
    exec = "figma-open %U";
    icon = ../../figma.png;
    terminal = false;
    mimeType = [ "x-scheme-handler/figma" ];
  };

  xdg.mimeApps.defaultApplications = {
    "x-scheme-handler/figma" = "figma.desktop";
  };

  # Add figma-open handler to handlr URL dispatcher.
  # The base handlr.toml is in modules/home.nix; this prepends the Figma rule.
  xdg.configFile."handlr/handlr.toml".text = lib.mkForce (let
    chrome = "google-chrome-stable";
  in ''
    [[handlers]]
    exec = "figma-open %u"
    regexes = ['https?://(www\.)?figma\.com(/.*)?']

    [[handlers]]
    exec = "${chrome} --profile-directory=\"Default\" %u"
    regexes = ['https?://(www\.)?(youtube\.com|youtu\.be)(/.*)?']

    [[handlers]]
    exec = "${chrome} --profile-directory=\"Profile 1\" %u"
    regexes = ['https?://.*']
  '');

  # Figma Chrome app downloads to a hidden staging dir; systemd
  # watches it, extracts .zips and moves everything else into ~/Downloads.
  systemd.user.paths.figma-auto-unzip = {
    Unit.Description = "Watch Figma downloads for new files";
    Path.DirectoryNotEmpty = "%h/.figma/Downloads";
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.figma-auto-unzip = {
    Unit.Description = "Move Figma exports into ~/Downloads";
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "figma-download-handler" ''
        # Wait for Chrome to finish writing (no .crdownload temp files)
        for i in $(seq 1 20); do
          ls "$HOME/.figma/Downloads"/*.crdownload >/dev/null 2>&1 || break
          sleep 0.5
        done
        sleep 0.3
        for f in "$HOME/.figma/Downloads"/*; do
          [ -f "$f" ] || continue
          case "$f" in
            *.crdownload) ;;
            *.zip) ${pkgs.unzip}/bin/unzip -o "$f" -d "$HOME/Downloads" && rm "$f" ;;
            *)     mv "$f" "$HOME/Downloads/" ;;
          esac
        done
      '';
    };
  };

  systemd.user.services.figma-agent = {
    Unit.Description = "Figma local font agent";
    Service = {
      ExecStart = "${pkgs.figma-agent}/bin/figma-agent";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── Touchpad ───────────────────────────────────────────────────

  systemd.user.services.niri-dwt-toggle = {
    Unit = {
      Description = "Disable touchpad DWT for apps that need pointer during typing (Figma, Magic Garden)";
      After = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "%h/.local/bin/niri-dwt-toggle";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ── Voxtype (push-to-talk dictation) ───────────────────────────

  programs.voxtype = {
    enable = true;
    package = voxtypePatched;
    model.name = "small.en";
    service.enable = true;
    settings = {
      hotkey = {
        enabled = true;
        key = "EVTEST_40";
        modifiers = [ "SUPER" ];
        mode = "push_to_talk";
      };
      audio.feedback = {
        enabled = true;
        theme = "${config.home.homeDirectory}/.local/share/voxtype/sounds/wispr";
        volume = 0.7;
      };
      output = {
        mode = "paste";
        paste_keys = "ctrl+shift+v";
      };
      output.notification.on_transcription = false;
      text.spoken_punctuation = true;
      whisper.language = "en";
    };
  };
}
