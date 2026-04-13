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
  # Set NOCTALIA_CONFIG_DIR for the systemd user session so noctalia
  # (spawned by niri) reads from the writable runtime copy.
  systemd.user.sessionVariables = {
    NOCTALIA_CONFIG_DIR = "${config.home.homeDirectory}/.local/share/noctalia-config";
  };
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
    # Noctalia config is copied (not symlinked) to a writable runtime
    # dir — noctalia overwrites settings.json at runtime, which would
    # dirty the dotfiles repo (noctalia-shell#2214).  See the
    # home.activation.noctalia-config block below.
    "fuzzel".source = link "config/fuzzel";
    "ghostty".source = link "config/ghostty";
    "lazygit".source = link "config/lazygit";
    "starship.toml".source = link "config/starship.toml";
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
    Color8=#8A9399
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
    Color8=#8A9399
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
      EXCLUDES="Brewfile config fish_variables gitconfig gitignore_global hooks hushlogin Library nixos PLAN.md rcrc README.md rules.velja-rules ssh vim"
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
    ghostty
    kitty.kitten   # just the kitten CLI (icat for image previews), not the terminal app
    tree
    tmux
    zellij
    ripgrep
    delta
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
    tree-sitter
    gcc # needed by tree-sitter to compile parsers
    gemini-cli
    zed-editor
    biome
    typescript-language-server

    # Wayland tools
    wl-clipboard
    ddcutil
    playerctl
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
    video-trimmer
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
      { timeout = 600; command = "${pkgs.niri-unstable}/bin/niri msg action power-off-monitors"; }
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

  # ── Clipboard persistence ───────────────────────────────────────
  # On Wayland the clipboard dies when the source process exits.
  # wl-clip-persist takes over ownership so content survives, which
  # also fixes paste mode for voxtype (whose wl-copy child gets
  # killed by systemd cgroup cleanup).
  systemd.user.services.wl-clip-persist = {
    Unit = {
      Description = "Keep Wayland clipboard after source exits";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.wl-clip-persist}/bin/wl-clip-persist --clipboard regular";
      Restart = "on-failure";
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ── Wayland environment gate ──────────────────────────────────────
  # When niri quits (logout, exit dialog, crash), niri-session runs
  # `systemctl --user unset-environment WAYLAND_DISPLAY` as cleanup.
  # niri.service then restarts automatically — but graphical-session.target
  # re-activates before niri finishes starting and re-exporting the
  # variable.  Every service bound to graphical-session.target (voxtype,
  # swayidle, niri-dwt-toggle, vicinae, polkit-badged, etc.) launches
  # into a session where WAYLAND_DISPLAY is gone, so wtype, wl-copy,
  # and `niri msg` all fail silently.
  #
  # On a fresh boot this doesn't happen — niri synchronously exports
  # the variable before sending sd_notify.  The bug is specific to
  # the restart path through niri-session's cleanup.
  #
  # This oneshot gates graphical-session.target by polling until
  # WAYLAND_DISPLAY appears in the systemd user environment (~50ms in
  # practice).  Same pattern as UWSM's wayland-session-waitenv.service.
  # See: https://github.com/Vladimir-csp/uwsm
  systemd.user.services.niri-wayland-env-gate = {
    Unit = {
      Description = "Wait for WAYLAND_DISPLAY in systemd environment";
      After = [ "niri.service" ];
      Before = [ "graphical-session.target" ];
      BindsTo = [ "graphical-session.target" ];
    };
    Service = {
      Type = "oneshot";
      RemainAfterExit = true;
      ExecStart = pkgs.writeShellScript "wait-wayland-env" ''
        for i in $(seq 1 50); do
          ${pkgs.systemd}/bin/systemctl --user show-environment | grep -q '^WAYLAND_DISPLAY=' && exit 0
          sleep 0.1
        done
        echo "WAYLAND_DISPLAY not found after 5s" >&2
        exit 1
      '';
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };

  # ── niri.service ExecStop drop-in ────────────────────────────────
  # Stop graphical-session.target *before* niri gets SIGTERM'd so PartOf=
  # services (xdg-desktop-portal etc.) can tear down cleanly while niri's
  # Wayland socket is still alive.  Without this, systemd-initiated stops
  # (logout, shutdown, `systemctl stop niri.service`) yank the socket out
  # from under dependents mid-shutdown and leave them in `failed` state,
  # which blocks auto-start on the next login.  Workaround for niri#2435.
  # https://github.com/niri-wm/niri/issues/2435
  #
  # Written as a raw drop-in via xdg.configFile (not
  # systemd.user.services.niri) because the latter injects a narrow
  # Environment=PATH= that would mask the user manager's PATH and break
  # niri's spawn-at-startup for user-profile tools like noctalia-shell.
  xdg.configFile."systemd/user/niri.service.d/50-execstop-graphical-session.conf".text = ''
    [Service]
    ExecStop=${pkgs.systemd}/bin/systemctl --user stop graphical-session.target
  '';

  # ── Noctalia config sync ──────────────────────────────────────────
  # Copy declarative noctalia config to a writable runtime directory.
  # Noctalia mutates its own settings.json at runtime (noctalia-shell
  # #2214), so we can't symlink into the dotfiles repo.  On each
  # home-manager activation, the declarative files overwrite the
  # runtime copy.  Use `noctalia-dump` to pull GUI changes back.
  home.activation.noctalia-config = lib.hm.dag.entryAfter [ "writeBoundary" ] ''
    NOCTALIA_RUNTIME="$HOME/.local/share/noctalia-config"
    NOCTALIA_SRC="${dotfiles}/config/noctalia"
    SETTINGS_SRC="${dotfiles}/config/noctalia_settings.json"

    mkdir -p "$NOCTALIA_RUNTIME/plugins"

    # Copy settings and plugin registry
    cp "$SETTINGS_SRC" "$NOCTALIA_RUNTIME/settings.json"
    cp "$NOCTALIA_SRC/plugins.json" "$NOCTALIA_RUNTIME/plugins.json"

    # Sync plugin directories
    for plugin in "$NOCTALIA_SRC"/plugins/*/; do
      name=$(basename "$plugin")
      rm -rf "$NOCTALIA_RUNTIME/plugins/$name"
      cp -r "$plugin" "$NOCTALIA_RUNTIME/plugins/$name"
    done

    # Copy colorschemes from ~/.config/noctalia (managed by noctalia.nix)
    if [ -d "$HOME/.config/noctalia/colorschemes" ]; then
      cp -r "$HOME/.config/noctalia/colorschemes" "$NOCTALIA_RUNTIME/"
    fi
  '';

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
