{
  config,
  pkgs,
  lib,
  inputs,
  desktop ? true,
  desktopPackageSegments ? {
    afterRcm = [];
    afterFzf = [];
    afterBtop = [];
    afterGemini = [];
    afterTypescript = [];
  },
  osConfig,
  ...
}:

let
  dotfiles = "${config.home.homeDirectory}/Projects/dotfiles";
  link = path: config.lib.file.mkOutOfStoreSymlink "${dotfiles}/${path}";
in
{
  imports = lib.optionals desktop [
    inputs.vicinae.homeManagerModules.default
    ./home-desktop.nix
  ];

  home.username = "aroman";
  home.homeDirectory = "/home/aroman";

  # CLI configuration shared by desktop and headless hosts.
  xdg.configFile = {
    "nvim".source = link "config/nvim";
    "fish".source = link "config/fish";
    "bat".source = link "config/bat";
    "lazygit".source = link "config/lazygit";
    "starship.toml".source = link "config/starship.toml";
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
      EXCLUDES="Brewfile config fish_variables gitconfig gitignore_global hooks hushlogin Library nixos PLAN.md rcrc README.md result rules.velja-rules ssh vim"
    '';
  };

  # One default-priority definition preserves the original merge position
  # relative to packages added automatically by Home Manager modules.
  home.packages = with pkgs; [
    # Shells & prompts
    starship

    # Core CLI
    rcm          # dotfile manager — `rcup` symlinks local/bin/* → ~/.local/bin/* etc.
  ] ++ lib.optionals desktop desktopPackageSegments.afterRcm ++ [
    # opener-bridged: when SSH'd in, `xdg-open URL` hands the URL to the Mac,
    # which opens it in the local browser — Velja then routes it just like
    # handlr-regex does here.  At the console the shim falls through to real
    # xdg-open → handlr → Chrome.
    #
    # 127.0.0.1:47831 is the mouth of a tunnel back to the Mac's opener-bridged
    # daemon (an opener-tunnel launchd job on the Mac holds it open).  One
    # line each way:
    #
    #   -> open <origin> <url>        <- ok <final-url>  |  err <message>
    #
    # The origin is load-bearing: `localhost:PORT` names a port on *this* box,
    # so the Mac has to forward that port before it can open anything.  It is
    # baked in at build time rather than read from $HOSTNAME, which bash sets
    # but fish — the login shell here — does not.
    #
    # The guard is "is there a screen attached to *this shell*", not
    # $SSH_CONNECTION.  herdr runs as a headless systemd user service, so its
    # shells are children of systemd and inherit no ssh environment at all —
    # they would fail the ssh test and open a browser on the tower's monitor
    # instead of on the Mac.  A compositor exports WAYLAND_DISPLAY to what it
    # spawns, so its absence means nobody is looking at a local screen here,
    # which is true of ssh and herdr alike.
    #
    # On a host that also runs a compositor, that absence is not automatic:
    # niri imports WAYLAND_DISPLAY into the *user manager's* environment, so a
    # unit restarted after login inherits it even though it inherits nothing
    # from any session.  hosts/wizardtower/home.nix clears it on herdr for
    # exactly this reason.
    #
    # Deliberately no falling through to the real xdg-open when the bridge is
    # down.  With no display and no bridge there is nowhere legitimate to open
    # anything, and failing loudly is the whole point: the previous version
    # piped into a socket file that outlived its daemon and exited 0, so
    # callers printed "✓ Opened" forever while nothing happened.
    (writeShellScriptBin "xdg-open" ''
      if [ -z "$WAYLAND_DISPLAY" ] && [ -z "$DISPLAY" ]; then
        resp=$(printf 'open %s %s\n' "${osConfig.networking.hostName}" "$1" \
          | ${netcat-openbsd}/bin/nc -N -w 10 127.0.0.1 47831 2>/dev/null)
        case "$resp" in
          "ok "*)  exit 0 ;;
          "err "*) echo "xdg-open: ''${resp#err }" >&2; exit 1 ;;
          *)       echo "xdg-open: opener bridge unreachable (127.0.0.1:47831)" >&2
                   exit 1 ;;
        esac
      fi
      exec ${xdg-utils}/bin/xdg-open "$@"
    '')
    bat
    eza
    fzf
  ] ++ lib.optionals desktop desktopPackageSegments.afterFzf ++ [
    kitty.kitten   # just the kitten CLI (icat for image previews), not the terminal app
    tree
    tmux
    zellij
    ripgrep
    delta
    difftastic
    fd
    jq
    # nixpkgs wraps gh to default GH_TELEMETRY, so os.Executable() sees the
    # versioned /nix/store/.../bin/.gh-wrapped implementation. Without this
    # override, `gh auth setup-git` persists that GC-vulnerable path in the
    # shared gitconfig instead of the portable `gh` command.
    (symlinkJoin {
      name = "gh-portable-path-${gh.version}";
      paths = [ gh ];
      nativeBuildInputs = [ makeWrapper ];
      postBuild = ''
        rm $out/bin/gh
        makeWrapper ${gh}/bin/gh $out/bin/gh \
          --set-default GH_PATH gh
      '';
      inherit (gh) meta;
    })
    git-lfs
    gnupg
    cloudflared
    btop
  ] ++ lib.optionals desktop desktopPackageSegments.afterBtop ++ [
    tokei
    unzip

    # Editor
    neovim
    tree-sitter
    gcc # needed by tree-sitter to compile parsers
    gemini-cli
  ] ++ lib.optionals desktop desktopPackageSegments.afterGemini ++ [
    biome
    typescript-language-server
  ] ++ lib.optionals desktop desktopPackageSegments.afterTypescript ++ [
    # Development
    nodejs_24
  ];

  services.gpg-agent.enable = true;

  programs.home-manager.enable = true;

  home.stateVersion = "24.11";
}
