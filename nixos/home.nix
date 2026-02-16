{ config, pkgs, lib, inputs, ... }:

let
  dotfiles = "${config.home.homeDirectory}/Projects/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  imports = [
    inputs.dms.homeModules.dank-material-shell
  ];

  home.username = "aroman";
  home.homeDirectory = "/home/aroman";
  home.shellAliases = {
    zed = "zededitor";
    vim = "nvim";
  };

  # ── Symlink existing dotfiles ──────────────────────────────────────

  # XDG config dirs (-> ~/.config/*)
  xdg.configFile = {
    "niri/config.kdl".source = link "config/niri/config.kdl";
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
  xdg.mimeApps = {
    enable = true;
    defaultApplications = {
      "text/plain" = "dev.zed.Zed.desktop";
      "application/x-zerosize" = "dev.zed.Zed.desktop";
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

    # Media & audio
    easyeffects
    pwvucontrol
    spotify
    vlc

    # Browsers
    firefox
    (google-chrome.override {
      commandLineArgs = [
        "--enable-features=TouchpadOverscrollHistoryNavigation"
        "--new-window"
      ];
    })

    # Communication
    vesktop

    nautilus
    adwaita-icon-theme

    # Terminal
    (blackbox-terminal.overrideAttrs (old: {
      patches = (old.patches or []) ++ [ ./blackbox-no-buttons.patch ];
    }))

    # Desktop shell & launcher
    vicinae

    # Development
    nodejs_22
    bun
  ];

  # ── DankMaterialShell ──────────────────────────────────────────────

  programs.dank-material-shell = {
    enable = true;
    systemd.enable = true;
    enableSystemMonitoring = true;
    enableDynamicTheming = true;
  };

  # ── GPG agent ──────────────────────────────────────────────────────

  services.gpg-agent = {
    enable = true;
    pinentry.package = pkgs.pinentry-gnome3;
  };

  # ── Dark mode (dconf/gsettings) ────────────────────────────────────

  dconf.settings = {
    "com/github/wwmm/easyeffects/streamoutputs" = {
      output-device = "auto_null";
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
  };

  # ── Let Home Manager manage itself ─────────────────────────────────

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
