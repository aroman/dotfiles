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
  home.shellAliases = {
    zed = "zededitor";
    vim = "nvim";
    bake = "sudo nixos-rebuild switch --flake ~/Projects/dotfiles/nixos";
  };

  # ── Symlink existing dotfiles ──────────────────────────────────────

  # XDG config dirs (-> ~/.config/*)
  xdg.configFile = {
    "niri/config.kdl".source = link "config/niri/config.kdl";
    "nvim".source = link "config/nvim";
    "zed".source = link "config/zed";
    "fish".source = link "config/fish";
    "bat".source = link "config/bat";
    "waybar".source = link "config/waybar";
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
  xdg.dataFile."blackbox/schemes/Everblush.json".force = true;
  xdg.dataFile."blackbox/schemes/Everblush.json".text = builtins.toJSON {
    name = "Everblush";
    comment = "A dark, vibrant, and beautiful color scheme.";
    use-theme-colors = false;
    foreground-color = "#DADADA";
    background-color = "#141B1E";
    palette = [
      "#232A2D" "#E57474" "#8CCF7E" "#E5C76B" "#67B0E8" "#C47FD5" "#6CBFBF" "#B3B9B8"
      "#2D3437" "#EF7E7E" "#96D988" "#F4D67A" "#71BAF2" "#CE89DF" "#67CBE7" "#BDC3C2"
    ];
  };
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
    exec = "google-chrome-stable --profile-directory=\"Profile 1\" --user-agent=\"Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/133.0.0.0 Safari/537.36\" --hide-crash-restore-bubble --app=https://www.figma.com %U";
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
    (blackbox-terminal.overrideAttrs (old: {
      patches = (old.patches or []) ++ [ ./blackbox-no-buttons.patch ];
    }))

    # Desktop shell & launcher
    vicinae
    waybar
    swaynotificationcenter

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
      monospace-font-name = "Cascadia Code NF 12";
    };
    "com/raggesilver/BlackBox" = {
      theme-dark = "Everblush";
      pretty = true;
      show-headerbar = true;
    };
  };

  # ── Environment variables ──────────────────────────────────────────

  home.sessionVariables = {
    EDITOR = "zeditor --wait";
    # Force Qt apps to use Adwaita dark theme (matches GTK dark mode set via dconf)
    QT_STYLE_OVERRIDE = "adwaita-dark";
  };

  # ── Let Home Manager manage itself ─────────────────────────────────

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
