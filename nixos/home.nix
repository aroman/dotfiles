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
    "easyeffects/output/Cab's_20Fav.json".source = link "Cab's_20Fav.json";
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
  xdg.dataFile."org.gnome.Ptyxis/palettes/one-dark.palette".text = ''
    [Palette]
    Name=One Dark

    [Dark]
    Foreground=#abb2bf
    Background=#0d1117
    Color0=#0d1117
    Color1=#e06c75
    Color2=#98c379
    Color3=#e5c07b
    Color4=#61afef
    Color5=#c678dd
    Color6=#56b6c2
    Color7=#abb2bf
    Color8=#545862
    Color9=#e06c75
    Color10=#98c379
    Color11=#e5c07b
    Color12=#61afef
    Color13=#c678dd
    Color14=#56b6c2
    Color15=#c8ccd4

    [Light]
    Foreground=#abb2bf
    Background=#0d1117
    Color0=#0d1117
    Color1=#e06c75
    Color2=#98c379
    Color3=#e5c07b
    Color4=#61afef
    Color5=#c678dd
    Color6=#56b6c2
    Color7=#abb2bf
    Color8=#545862
    Color9=#e06c75
    Color10=#98c379
    Color11=#e5c07b
    Color12=#61afef
    Color13=#c678dd
    Color14=#56b6c2
    Color15=#c8ccd4
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
    swaylock
    brightnessctl
    playerctl
    networkmanagerapplet
    overskride

    # Media & audio
    easyeffects
    pwvucontrol
    spotify
    celluloid

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
    "com/github/wwmm/easyeffects/streamoutputs" = {
      output-device = "alsa_output.pci-0000_c2_00.6.HiFi__Speaker__sink";
      last-used-output-preset = "Cab's_20Fav";
      use-default-output-preset = true;
    };
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      gtk-theme = "Adwaita-dark";
      accent-color = "blue";
      font-name = "Inter 11";
      monospace-font-name = "Cascadia Code NF 12";
      cursor-theme = "Adwaita";
      cursor-size = 24;
    };
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
