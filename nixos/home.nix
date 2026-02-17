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
  # Windows user-agent tricks Figma into talking to figma-agent for local fonts.
  xdg.desktopEntries.figma = {
    name = "Figma";
    comment = "Figma (Chrome app mode)";
    exec = "google-chrome-stable --user-data-dir=${config.home.homeDirectory}/.config/figma-chrome --user-agent=\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/145.0.0.0 Safari/537.36\" --hide-crash-restore-bubble --app=https://www.figma.com %U";
    icon = ./figma.png;
    terminal = false;
    mimeType = [ "x-scheme-handler/figma" ];
  };

  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "dev.zed.Zed.desktop";
      "application/x-zerosize" = "dev.zed.Zed.desktop";
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
  };

  # ── User packages ──────────────────────────────────────────────────

  home.packages = with pkgs; [
    # Shells & prompts
    starship

    # Core CLI
    bat
    fzf
    ripgrep
    fd
    jq
    gh
    git-lfs
    gnupg
    tokei
    yt-dlp
    unzip

    # Editor
    neovim
    zed-editor

    # Wayland tools
    wl-clipboard
    brightnessctl
    playerctl
    networkmanagerapplet
    overskride

    # Media & audio
    pwvucontrol
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

    # Design
    figma-agent # serves local fonts to Figma web (needs Windows user-agent)
    texturepacker
    adwaita-qt6

    nautilus
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
      cursor-theme = "Adwaita";
      cursor-size = 24;
    };
    # TODO: manage Ptyxis settings declaratively (dconf module doesn't re-apply after manual changes)
  };

  # ── Services ─────────────────────────────────────────────────────

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

  # ── Environment variables ──────────────────────────────────────────

  home.sessionVariables = {
    EDITOR = "zeditor --wait";
  };

  # ── Programs ─────────────────────────────────────────────────────

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
