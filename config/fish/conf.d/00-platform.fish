if status --is-interactive; and test (uname) = Darwin
    eval (/opt/homebrew/bin/brew shellenv)
end

if test (uname) = Darwin
    set -g DOTFILES_DIR ~/.dotfiles
else
    set -g DOTFILES_DIR ~/Projects/dotfiles
end

if command -q zeditor
    set -gx EDITOR "zeditor -w"
else if command -q zed
    set -gx EDITOR "zed -w"
else if command -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end

set -g nvm_default_version lts

if test (uname) = Linux
    alias zed="zeditor"
    alias bake="sudo nixos-rebuild switch --flake $DOTFILES_DIR/nixos && rcup -K"
    alias yt-dlp="nix run nixpkgs#yt-dlp --"
    alias codex="nix run github:sadjow/codex-cli-nix --"
    alias claude="nix run github:sadjow/claude-code-nix --"
end

set -x GPG_TTY (tty)
set -x DFT_DISPLAY side-by-side-show-both
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

if test (uname) = Darwin
    # Added by OrbStack: command-line tools and integration.
    source ~/.orbstack/shell/init2.fish 2>/dev/null || :

    fish_add_path /Applications/Tailscale.app/Contents/MacOS
    fish_add_path /Users/aroman/.antigravity/antigravity/bin
    fish_add_path /opt/homebrew/opt/libpq/bin
end

source "$HOME/.cargo/env.fish" 2>/dev/null

fish_add_path ~/.local/bin
fish_add_path -g /Users/aroman/.local/bin
