{ config, pkgs, lib, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/Projects/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  imports = [
    inputs.vicinae.homeManagerModules.default
    inputs.lan-mouse.homeManagerModules.default
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
    "fuzzel".source = link "config/fuzzel";
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
  # Override the flatpak-exported desktop file (which lacks -platform wayland)
  # by placing ours in ~/.local/share/applications/ where it takes XDG priority.
  xdg.dataFile."applications/com.codeandweb.texturepacker.desktop".force = true;
  xdg.dataFile."applications/com.codeandweb.texturepacker.desktop".text = ''
    [Desktop Entry]
    Name=TexturePacker
    GenericName=Sprite Sheet Creator
    Exec=TexturePacker -platform wayland --gui %F
    Icon=com.codeandweb.texturepacker
    Terminal=false
    Type=Application
    Categories=Development
    MimeType=application/vnd.codeandweb.de.tps;application/vnd.codeandweb.de.pvr;application/vnd.codeandweb.de.pvr.ccz;application/vnd.codeandweb.de.pvr.gz
  '';
  xdg.dataFile."applications/flatpak-install.desktop".text = ''
    [Desktop Entry]
    Name=Flatpak Install
    Exec=flatpak-install %u
    Terminal=true
    Type=Application
    NoDisplay=true
    MimeType=application/vnd.flatpak.ref
  '';
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
  xdg.desktopEntries.linear = {
    name = "Linear";
    comment = "Linear (Chrome app mode)";
    exec = "google-chrome-stable --user-data-dir=${config.home.homeDirectory}/.config/linear-chrome --hide-crash-restore-bubble --app=https://linear.app %U";
    icon = ../linear.png;
    terminal = false;
    mimeType = [];
  };

  xdg.desktopEntries.rive = {
    name = "Rive";
    comment = "Rive (Chrome app mode)";
    exec = "google-chrome-stable --user-data-dir=${config.home.homeDirectory}/.config/rive-chrome --hide-crash-restore-bubble --app=https://editor.rive.app %U";
    icon = ../rive.png;
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
      "application/vnd.flatpak.ref" = "flatpak-install.desktop";
    };
  };

  # Home directory dotfiles (-> ~/.<name>)
  home.file = {
    ".gitconfig".source = link "gitconfig";
    ".gitignore_global".source = link "gitignore_global";
    ".vim".source = link "vim";
    ".ssh/config".source = link "ssh/config";
    # On NixOS, home-manager owns most dotfiles — rcup only manages local/.
    # On macOS there's no ~/.rcrc so rcup manages everything.
    ".rcrc".text = ''
      DOTFILES_DIRS="$HOME/Projects/dotfiles"
      EXCLUDES="Brewfile config gitconfig gitignore_global hooks hushlogin Library nixos PLAN.md README.md rules.velja-rules ssh vim"
    '';
  };

  # ── User packages ──────────────────────────────────────────────────

  home.packages = with pkgs; [
    # Shells & prompts
    starship

    # Core CLI
    rcm          # dotfile manager — `rcup` symlinks local/bin/* → ~/.local/bin/* etc.
    handlr-regex # URL dispatcher — routes links to the right app by domain
    bat
    eza
    fzf
    kitty   # for `kitten icat` (image previews in fzf)
    tree
    ripgrep
    difftastic
    fd
    jq
    gh
    git-lfs
    gnupg
    cloudflared
    btop
    tokei
    unzip

    # Editor
    neovim
    zed-editor
    typescript-language-server

    # Wayland tools
    wl-clipboard
    ddcutil
    playerctl
    networkmanagerapplet
    overskride
    socat # IPC with niri socket (used by swap-monitors script)
    fuzzel       # Wayland dmenu/rofi — used for worktree picker etc.
    xdg-terminal-exec # XDG default terminal launcher — used by batman-picker
    slurp        # area selection for screen recording
    wf-recorder  # Wayland screen recorder
    libnotify    # notify-send for desktop notifications

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

    # Design
    gradia
    texturepacker
    adwaita-qt6
    adw-gtk3 # libadwaita look for GTK3 apps (Nemo, Thunar, etc.)

    nautilus
    file-roller
    loupe
    snapshot
    papers
    mission-center
    font-manager
    adwaita-icon-theme

    # Terminal (50.rc for enable-zoom-scroll-ctrl setting)
    (ptyxis.overrideAttrs (old: {
      version = "50.rc";
      src = old.src.override {
        tag = "50.rc";
        hash = "sha256-0StYVSQt0LCAW9WUugIQuBKac1dri+96XE69fMracPo=";
      };
      patches = (old.patches or []) ++ [ ../ptyxis-no-headerbar.patch ];
    }))

    # Desktop shell & launcher
    # vicinae — installed via services.vicinae below

    # Development
    nodejs_22

    # Clipboard sharing (text + images, native Wayland via ext-data-control-v1)
    # Update hashes: nix build will show the correct hash on first failure
    (pkgs.buildGoModule {
      pname = "belphegor";
      version = "3.6.1";
      src = pkgs.fetchFromGitHub {
        owner = "labi-le";
        repo = "belphegor";
        rev = "v3.6.1";
        hash = "sha256-NyDpSz0Zzk1FzG1F3WXV2aYZGXloyMHZqmTEBG/Oz+4=";
      };
      vendorHash = "sha256-t/hg0umkEGIawgZ/AKNvGXvmxQph71qbQbIoIQ7UfV0=";
      subPackages = [ "cmd/cli" ];
      postInstall = ''
        mv $out/bin/cli $out/bin/belphegor
      '';
      meta.description = "P2P clipboard sharing with image support";
    })
  ];


  # ── Vicinae launcher ─────────────────────────────────────────────

  services.vicinae = {
    enable = true;
    systemd = {
      enable = true;
      autoStart = true;
      environment = {
        USE_LAYER_SHELL = 1;
      };
    };
  };



  # ── lan-mouse (mouse/keyboard sharing with macOS) ────────────────
  programs.lan-mouse = {
    enable = true;
    systemd = true;
    settings = {
      port = 4242;
      authorized_fingerprints = {
        "ee:93:9b:4d:29:f0:d7:1c:10:3a:a3:7a:9d:08:da:64:18:ee:4a:4c:6f:e3:91:10:95:4d:f2:5e:ef:0e:10:8a" = "dawnbinder";
      };
      clients = [
        {
          hostname = "dawnbinder.local";
          position = "left";
          activate_on_startup = true;
          ips = [ "192.168.4.172" ];
        }
      ];
    };
  };

  # ── GPG agent ──────────────────────────────────────────────────────

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # ── Dark mode & GTK settings (dconf/gsettings) ─────────────────────

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "adw-gtk3-dark";
      accent-color = "blue";
      font-name = "Inter 11";
      monospace-font-name = "CaskaydiaCove Nerd Font 12";
      icon-theme = "Adwaita";
      cursor-theme = "Adwaita";
      cursor-size = 24;
      gtk-enable-primary-paste = false;
    };
    # TODO: manage Ptyxis settings declaratively (dconf module doesn't re-apply after manual changes)
    "org/gnome/Ptyxis" = {
      enable-zoom-scroll-ctrl = false;
    };
    "org/gnome/nautilus/preferences" = {
      default-sort-order = "mtime";
      default-sort-in-reverse-order = true;
    };
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
    timeouts = [
      # Power off monitors after 10 minutes idle.
      # Any input (mouse move, keypress) wakes them back up.
      { timeout = 600; command = "niri msg action power-off-monitors"; }
      # Lock the session after 15 minutes idle.
      { timeout = 900; command = "noctalia-shell ipc call lockScreen lock"; }
    ];
    events = {
      # Lock the session before systemd suspends (lid close, idle, manual).
      # swayidle's delay inhibitor holds off sleep until this returns.
      before-sleep = "noctalia-shell ipc call lockScreen lock";
      # Also lock when any external caller does `loginctl lock-session`.
      lock = "noctalia-shell ipc call lockScreen lock";
    };
  };

  # ── Services ─────────────────────────────────────────────────────

  # ── Belphegor (clipboard sharing) ────────────────────────────────
  # Belphegor disabled as auto-start service (memory leak ~5GB).
  # Run manually via `clipboard-sync` fish function instead.

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

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
