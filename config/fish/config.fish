# vim: set ts=4


if status --is-interactive; and test (uname) = Darwin
  eval (/opt/homebrew/bin/brew shellenv)
end

set fish_greeting ""

# Solarized color theme
set -g fish_color_autosuggestion 586e75
set -g fish_color_cancel -r
set -g fish_color_command 93a1a1
set -g fish_color_comment 586e75
set -g fish_color_end 268bd2
set -g fish_color_error dc322f
set -g fish_color_escape 00a6b2
set -g fish_color_history_current --bold
set -g fish_color_match --background=brblue
set -g fish_color_normal normal
set -g fish_color_operator 00a6b2
set -g fish_color_param 839496
set -g fish_color_quote 657b83
set -g fish_color_redirection 6c71c4
set -g fish_color_search_match bryellow --background=black
set -g fish_color_selection white --bold --background=brblack
set -g fish_color_valid_path --underline
set -g fish_pager_color_completion B3A06D
set -g fish_pager_color_description B3A06D
set -g fish_pager_color_prefix cyan --underline
set -g fish_pager_color_progress brwhite --background=cyan

# nvm
set -g nvm_default_version lts
if command -q zeditor
    set -gx EDITOR "zeditor -w"
else if command -q zed
    set -gx EDITOR "zed -w"
else if command -q vim
    set -gx EDITOR vim
else
    set -gx EDITOR vi
end
starship init fish | source

alias cat="bat --paging=never"
alias vim="nvim"
if test (uname) = Linux
    alias zed="zeditor"
end
if test (uname) = Linux
    alias bake="sudo nixos-rebuild switch --flake ~/Projects/dotfiles/nixos && rcup -K"
    alias yt-dlp="nix run nixpkgs#yt-dlp --"
    alias codex="nix run github:sadjow/codex-cli-nix --"
    alias claude="nix run github:sadjow/claude-code-nix --"
end

abbr --add wrangler "pnpm wrangler"
abbr --add a "rg -i"
abbr --add hack "zed ."
abbr --add exifscrub "exiftool -all= "

abbr --add gg "cd ~/Projects/magiccircle.gg"

if test (uname) = Darwin
    abbr --add serve "open 'http://127.0.0.1:8080' && bunx http-server ."
else
    abbr --add serve "xdg-open 'http://127.0.0.1:8080' && bunx http-server ."
end
abbr --add yolo "claude --dangerously-skip-permissions"
abbr --add gs "git status"
abbr --add gl "git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

function killport
    set port $argv[1]
    set pids (lsof -ti :$port)
    if test -n "$pids"
        for pid in $pids
            kill -9 $pid
            echo "Killed process $pid listening on port $port"
        end
    else
        echo "No process found listening on port $port"
    end
end

# GPG Key Setup
set -x GPG_TTY (tty)

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# macOS-only integrations
if test (uname) = Darwin
    # Added by OrbStack: command-line tools and integration
    # This won't be added again if you remove it.
    source ~/.orbstack/shell/init2.fish 2>/dev/null || :

    test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish ; or true

    # Added by Antigravity
    fish_add_path /Users/aroman/.antigravity/antigravity/bin
end

source "$HOME/.cargo/env.fish" 2>/dev/null

export PATH="$HOME/.local/bin:$PATH"
