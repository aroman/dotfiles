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
    vesktop

    # Passwords
    _1password-gui
    _1password-cli

    # Terminal
    ptyxis

    # Desktop shell & launcher
    vicinae
    noctalia-shell

    # Development
    nodejs_22
    bun
  ];

  # ── GPG agent ──────────────────────────────────────────────────────

  services.gpg-agent = {
    enable = true;
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
  };

  # ── Let Home Manager manage itself ─────────────────────────────────

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
