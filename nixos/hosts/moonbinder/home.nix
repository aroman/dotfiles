{ config, pkgs, lib, inputs, ... }:

{
  imports = [
    ../../modules/home.nix
    ../../modules/opener-bridged.nix
    inputs.voxtype.homeManagerModules.default
  ];

  home.sessionVariables.JAVA_HOME = "${pkgs.jdk17}";

  home.packages = (with pkgs; [
    jdk17
    brightnessctl
    websocat     # WebSocket CLI — used by figma-open to navigate via CDP
    figma-agent  # serves local fonts to Figma web (needs Windows user-agent)
    discord
    slack
  ]) ++ [
    inputs.spotifast.packages.${pkgs.stdenv.hostPlatform.system}.default
    # FHS variant: gives Cowork the QEMU/OVMF/virtiofsd it probes for at
    # /usr paths, and MCP servers a normal node/uv/docker.
    #
    # Electron picks its keyring from XDG_CURRENT_DESKTOP and doesn't know
    # "niri", so it refuses to persist sign-in ("Install and unlock a system
    # keyring"). CLAUDE_PASSWORD_STORE is the package's hook for
    # --password-store. The .desktop Exec is PATH-relative, so launchers
    # pick up this wrapper without rewriting it.
    (pkgs.symlinkJoin {
      name = "claude-desktop-fhs-libsecret";
      paths = [ pkgs.claude-desktop-fhs ];
      nativeBuildInputs = [ pkgs.makeWrapper ];
      postBuild = ''
        rm $out/bin/claude-desktop
        makeWrapper ${pkgs.claude-desktop-fhs}/bin/claude-desktop $out/bin/claude-desktop \
          --set-default CLAUDE_PASSWORD_STORE gnome-libsecret
      '';
    })
    (pkgs.callPackage ./chatgpt-bin.nix { })
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
    # Claude Desktop tries to claim this itself on every launch, but
    # mimeapps.list is read-only here. Needed for sign-in callbacks.
    "x-scheme-handler/claude" = "com.anthropic.Claude.desktop";
  };

  # Add figma-open handler to handlr URL dispatcher.
  # The base handlr.toml is in modules/home-desktop.nix; this prepends the Figma rule.
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
    package = pkgs.callPackage ./voxtype-bin.nix { };
    model.name = "small.en";
    service.enable = true;
    settings = {
      hotkey = {
        enabled = true;
        key = "EVTEST_40";
        modifiers = [ "SUPER" ];
        mode = "push_to_talk";
      };
      audio.max_duration_secs = 600;
      audio.feedback = {
        enabled = true;
        theme = "${config.home.homeDirectory}/.local/share/voxtype/sounds/wispr";
        volume = 0.7;
      };
      # Paste mode: copy the transcript, then send Shift+Insert (type mode is
      # char-by-char, too slow). Shift+Insert is the one paste key terminals
      # and GUI apps share — Ctrl+Shift+V misses Nautilus, Ctrl+V misses
      # terminals. Ghostty is rebound to paste the clipboard on it
      # (config/ghostty/config). The clipboard outlives voxtype's wl-copy via
      # wl-clip-persist (modules/home-desktop.nix).
      output = {
        mode = "paste";
        paste_keys = "shift+insert";
      };
      output.notification.on_transcription = false;
      text.spoken_punctuation = true;
      whisper.language = "en";
    };
  };

  # Pin voxtype to the FW16 internal mic so docking a headset/dock doesn't
  # silently steal input. pipewire-alsa honors PIPEWIRE_NODE at open time.
  systemd.user.services.voxtype.Service.Environment = [
    "PIPEWIRE_NODE=alsa_input.pci-0000_c3_00.6.HiFi__Mic1__source"
  ];
}
