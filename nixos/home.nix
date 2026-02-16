{ config, pkgs, lib, ... }:

let
  dotfiles = "${config.home.homeDirectory}/.dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  home.username = "aroman";
  home.homeDirectory = "/home/aroman";

  # ── Symlink existing dotfiles ──────────────────────────────────────

  # XDG config dirs (-> ~/.config/*)
  xdg.configFile = {
    "niri/config.kdl".source = link "config/niri/config.kdl";
    "nvim".source = link "config/nvim";
    "zed".source = link "config/zed";
    "fish".source = link "config/fish";
    "bat".source = link "config/bat";
    "environment.d".source = link "config/environment.d";
  };

  # Home directory dotfiles (-> ~/.<name>)
  home.file = {
    ".gitconfig".source = link "gitconfig";
    ".gitignore_global".source = link "gitignore_global";
    ".vim".source = link "vim";
    ".ssh/config".source = link "ssh/config";
    ".local/bin/pinentry-auto" = {
      source = link "local/bin/pinentry-auto";
      executable = true;
    };
  };

  # ── User packages ──────────────────────────────────────────────────

  home.packages = with pkgs; [
    # Shells & prompts
    starship
    fish

    # Core CLI
    bat
    fzf
    ripgrep
    fd
    jq
    gh
    git-lfs
    tokei
    yt-dlp

    # Editor
    neovim
    zed-editor

    # Wayland tools
    wl-clipboard
    swaylock
    fuzzel
    brightnessctl
    playerctl

    # Media & audio
    easyeffects
    spotify
    vlc

    # Browsers
    firefox
    google-chrome

    # Communication
    vesktop        # Discord client

    # Passwords
    _1password-gui
    _1password-cli

    # Terminal
    ptyxis

    # Development
    nodejs_22
    bun
    gnumake
    gcc

    # TODO: vicinae and noctalia-shell (qs) — these may need custom packages
    # or manual installation if not in nixpkgs. Check:
    #   nix search nixpkgs vicinae
    #   nix search nixpkgs noctalia
  ];

  # ── GPG agent ──────────────────────────────────────────────────────

  services.gpg-agent = {
    enable = true;
    defaultCacheTtl = 3600;
    maxCacheTtl = 7200;
    pinentryPackage = pkgs.pinentry-gnome3;
  };

  # ── Dark mode (dconf/gsettings) ────────────────────────────────────

  dconf.settings = {
    "org/gnome/desktop/interface" = {
      color-scheme = "prefer-dark";
      accent-color = "blue";
    };
  };

  # ── Environment variables ──────────────────────────────────────────

  home.sessionVariables = {
    EDITOR = "nvim";
    GPG_TTY = "$(tty)";
  };

  # ── Let Home Manager manage itself ─────────────────────────────────

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
