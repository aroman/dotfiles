{ config, pkgs, lib, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/Projects/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  imports = [
  ];

  home.username = "aroman";
  home.homeDirectory = "/home/aroman";
  home.pointerCursor = {
    name = "Adwaita";
    package = pkgs.adwaita-icon-theme;
    size = 24;
    gtk.enable = true;
  };

  # ── Symlink existing dotfiles ──────────────────────────────────────

  # XDG config dirs (-> ~/.config/*)
  xdg.configFile = {
    "niri".source = link "config/niri";
    "nvim".source = link "config/nvim";
    "zed".source = link "config/zed";
    "fish".source = link "config/fish";
    "bat".source = link "config/bat";
    "noctalia/settings.json".source = link "config/noctalia_settings.json";
  };

  xdg.desktopEntries."dev.zed.Zed" = {
    name = "Zed";
    genericName = "Text Editor";
    comment = "A high-performance, multiplayer code editor.";
    exec = "zeditor --new %U";
    icon = "zed";
    terminal = false;
    type = "Application";
    categories = [ "Utility" "TextEditor" "Development" "IDE" ];
    mimeType = [ "text/plain" "application/x-zerosize" "x-scheme-handler/zed" ];
    startupNotify = true;
  };

  # Hide neovim's desktop entry from app launchers and "Open With" dialogs
  xdg.desktopEntries.nvim = {
    name = "Neovim wrapper";
    exec = "nvim %F";
    terminal = true;
    noDisplay = true;
    mimeType = [];
  };

  xdg.configFile."mimeapps.list".force = true;
  xdg.dataFile."applications/mimeapps.list".force = true;
  xdg.dataFile."org.gnome.Ptyxis/palettes/everblush-custom.palette".text = ''
    [Palette]
    Name=Everblush Custom

    [Dark]
    Background=#141B1E
    Foreground=#DADADA
    Color0=#232A2D
    Color1=#E57474
    Color2=#8CCF7E
    Color3=#E5C76B
    Color4=#67B0E8
    Color5=#C47FD5
    Color6=#6CBFBF
    Color7=#B3B9B8
    Color8=#2D3437
    Color9=#EF7E7E
    Color10=#96D988
    Color11=#F4D67A
    Color12=#71BAF2
    Color13=#CE89DF
    Color14=#67CBE7
    Color15=#BDC3C2
    SuperuserBackground=#1C0A0C
    SuperuserForeground=#DADADA

    [Light]
    Background=#141B1E
    Foreground=#DADADA
    Color0=#232A2D
    Color1=#E57474
    Color2=#8CCF7E
    Color3=#E5C76B
    Color4=#67B0E8
    Color5=#C47FD5
    Color6=#6CBFBF
    Color7=#B3B9B8
    Color8=#2D3437
    Color9=#EF7E7E
    Color10=#96D988
    Color11=#F4D67A
    Color12=#71BAF2
    Color13=#CE89DF
    Color14=#67CBE7
    Color15=#BDC3C2
    SuperuserBackground=#1C0A0C
    SuperuserForeground=#DADADA
  '';
  xdg.desktopEntries."com.codeandweb.texturepacker" = {
    name = "TexturePacker";
    genericName = "Sprite Sheet Creator";
    exec = "TexturePacker -platform wayland --gui %F";
    icon = "com.codeandweb.texturepacker";
    terminal = false;
    categories = [ "Development" ];
    mimeType = [
      "application/vnd.codeandweb.de.tps"
      "application/vnd.codeandweb.de.pvr"
      "application/vnd.codeandweb.de.pvr.ccz"
      "application/vnd.codeandweb.de.pvr.gz"
    ];
  };

  # Figma via Chrome app mode instead of figma-linux (Electron).
  # Chrome --app is noticeably faster on Wayland/niri.
  # figma-open handles both launching and URL deep-linking via CDP.
  xdg.desktopEntries.figma = {
    name = "Figma";
    comment = "Figma (Chrome app mode)";
    exec = "figma-open %U";
    icon = ./figma.png;
    terminal = false;
    mimeType = [ "x-scheme-handler/figma" ];
  };

  xdg.desktopEntries.linear = {
    name = "Linear";
    comment = "Linear (Chrome app mode)";
    exec = "google-chrome-stable --user-data-dir=${config.home.homeDirectory}/.config/linear-chrome --hide-crash-restore-bubble --app=https://linear.app %U";
    icon = ./linear.png;
    terminal = false;
    mimeType = [];
  };

  xdg.desktopEntries.rive = {
    name = "Rive";
    comment = "Rive (Chrome app mode)";
    exec = "google-chrome-stable --user-data-dir=${config.home.homeDirectory}/.config/rive-chrome --hide-crash-restore-bubble --app=https://editor.rive.app %U";
    icon = ./rive.png;
    terminal = false;
    mimeType = [];
  };

  # ── URL dispatcher (handlr-regex) ─────────────────────────────────
  # Routes https:// links to the right app by domain regex.
  # handlr.desktop is the default handler for http/https; it checks
  # regex rules and falls through to Chrome for everything else.
  xdg.desktopEntries.handlr = {
    name = "URL Dispatcher";
    comment = "Routes URLs to the right app (handlr-regex)";
    exec = "handlr open %u";
    terminal = false;
    noDisplay = true;
    mimeType = [ "x-scheme-handler/http" "x-scheme-handler/https" ];
  };

  xdg.configFile."handlr/handlr.toml".text = let
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
  '';

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "dev.zed.Zed.desktop";
      "application/x-zerosize" = "dev.zed.Zed.desktop";
      "x-scheme-handler/http" = "handlr.desktop";
      "x-scheme-handler/https" = "handlr.desktop";
      "x-scheme-handler/figma" = "figma.desktop";
      "image/png" = "org.gnome.Loupe.desktop";
      "image/jpeg" = "org.gnome.Loupe.desktop";
      "image/gif" = "org.gnome.Loupe.desktop";
      "image/webp" = "org.gnome.Loupe.desktop";
      "image/avif" = "org.gnome.Loupe.desktop";
      "image/svg+xml" = "org.gnome.Loupe.desktop";
      "image/bmp" = "org.gnome.Loupe.desktop";
      "image/tiff" = "org.gnome.Loupe.desktop";
      "image/heic" = "org.gnome.Loupe.desktop";
      "image/vnd.microsoft.icon" = "org.gnome.Loupe.desktop";
    };
  };

  # Home directory dotfiles (-> ~/.<name>)
  home.file = {
    ".gitconfig".source = link "gitconfig";
    ".gitignore_global".source = link "gitignore_global";
    ".vim".source = link "vim";
    ".ssh/config".source = link "ssh/config";
    ".local/bin/pinentry-auto" = {
      source = link "local/bin/pinentry-auto";
     # executable = true;
    };
    ".local/bin/stack-terminal" = {
      source = link "local/bin/stack-terminal";
    };
    ".local/bin/dsp-toggle" = {
      source = link "local/bin/dsp-toggle";
    };
    ".local/bin/dictate" = {
      source = link "local/bin/dictate";
    };
    ".local/bin/dictate-transcribe" = {
      source = link "local/bin/dictate-transcribe";
    };
    ".local/bin/figma-open" = {
      source = link "local/bin/figma-open";
    };
  };

  # ── User packages ──────────────────────────────────────────────────

  home.packages = with pkgs; [
    # Shells & prompts
    starship

    # Core CLI
    handlr-regex # URL dispatcher — routes links to the right app by domain
    websocat     # WebSocket CLI — used by figma-open to navigate via CDP
    bat
    fzf
    ripgrep
    fd
    jq
    gh
    git-lfs
    gnupg
    tokei
    unzip

    # Editor
    neovim
    zed-editor

    # Dictation (speech-to-text)
    wtype
    (python3.withPackages (ps: [ ps.faster-whisper ]))

    # Wayland tools
    wl-clipboard
    brightnessctl
    playerctl
    networkmanagerapplet
    overskride
    socat # IPC with niri socket (used by swap-monitors script)

    # Media & audio
    pwvucontrol # TODO: missing icons (emblem-default-symbolic) — https://github.com/saivert/pwvucontrol/issues/71
    spotify
    celluloid
    newsflash

    # Browsers
    firefox
    (google-chrome.override {
      commandLineArgs = [
        "--enable-features=TouchpadOverscrollHistoryNavigation"
        "--new-window"
        "--hide-crash-restore-bubble"
      ];
    })

    # Communication
    vesktop
    slack

    # Design
    figma-agent # serves local fonts to Figma web (needs Windows user-agent)
    texturepacker
    adwaita-qt6

    nautilus
    file-roller
    loupe
    snapshot
    papers
    mission-center
    font-manager
    adwaita-icon-theme

    # Terminal
    (ptyxis.overrideAttrs (old: {
      patches = (old.patches or []) ++ [ ./ptyxis-no-headerbar.patch ];
    }))

    # Desktop shell & launcher
    vicinae

    # Development
    nodejs_22
    bun
  ];


  # ── GPG agent ──────────────────────────────────────────────────────

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # ── Dark mode (dconf/gsettings) ────────────────────────────────────

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      accent-color = "blue";
      font-name = "Inter 11";
      monospace-font-name = "CaskaydiaCove Nerd Font 12";
      icon-theme = "Adwaita";
      cursor-theme = "Adwaita";
      cursor-size = 24;
    };
    # TODO: manage Ptyxis settings declaratively (dconf module doesn't re-apply after manual changes)
  };

  # ── Idle & lock-before-sleep ──────────────────────────────────────
  # Niri has no built-in sleep inhibitor or lock-before-sleep mechanism
  # (only an async `switch-events { lid-close }` that races with logind's
  # suspend — see noctalia-shell#1066). swayidle takes a logind "sleep"
  # delay inhibitor, guaranteeing the lock command completes before the
  # system actually suspends.
  # Ref: https://github.com/niri-wm/niri/wiki/Example-systemd-Setup
  # Ref: https://man.archlinux.org/man/swayidle.1
  services.swayidle = {
    enable = true;
    events = [
      # Lock the session before systemd suspends (lid close, idle, manual).
      # swayidle's delay inhibitor holds off sleep until this returns.
      { event = "before-sleep"; command = "noctalia-shell ipc call lockScreen lock"; }
      # Also lock when any external caller does `loginctl lock-session`.
      { event = "lock"; command = "noctalia-shell ipc call lockScreen lock"; }
    ];
  };

  # ── Services ─────────────────────────────────────────────────────

  # ── Figma auto-unzip ─────────────────────────────────────────────
  # Figma Chrome app downloads .zips to a hidden staging dir; systemd
  # watches it and extracts contents into ~/Downloads automatically.
  systemd.user.paths.figma-auto-unzip = {
    Unit.Description = "Watch Figma downloads for .zip files";
    Path.DirectoryNotEmpty = "%h/.figma/Downloads";
    Install.WantedBy = [ "default.target" ];
  };
  systemd.user.services.figma-auto-unzip = {
    Unit.Description = "Extract Figma .zip exports into ~/Downloads";
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "figma-auto-unzip" ''
        for f in "$HOME/.figma/Downloads"/*.zip; do
          [ -f "$f" ] || continue
          sleep 0.5
          ${pkgs.unzip}/bin/unzip -o "$f" -d "$HOME/Downloads" && rm "$f"
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

  # ── Portal permissions ────────────────────────────────────────────
  # xdg-desktop-portal-gnome can't show the "allow camera?" dialog
  # outside a full GNOME session (no org.gnome.Shell on niri), so we
  # grant camera access directly in the permission store on startup.
  systemd.user.services.portal-camera-permission = let
    dbus-send = "${pkgs.dbus}/bin/dbus-send";
    grant = app: ''
      ${dbus-send} --session \
        --dest=org.freedesktop.impl.portal.PermissionStore \
        --type=method_call \
        /org/freedesktop/impl/portal/PermissionStore \
        org.freedesktop.impl.portal.PermissionStore.SetPermission \
        string:devices boolean:true string:camera \
        string:${app} array:string:yes
    '';
    cameraApps = [
      "org.gnome.Snapshot"
    ];
  in {
    Unit = {
      Description = "Grant camera permission in XDG portal store";
      After = [ "xdg-desktop-portal.service" ];
    };
    Service = {
      Type = "oneshot";
      ExecStart = pkgs.writeShellScript "grant-camera-permissions" ''
        ${lib.concatMapStringsSep "\n" grant cameraApps}
      '';
    };
    Install.WantedBy = [ "default.target" ];
  };

  # ── Programs ─────────────────────────────────────────────────────

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
