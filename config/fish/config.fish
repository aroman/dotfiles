# vim: set ts=4


if status --is-interactive; and test (uname) = Darwin
  eval (/opt/homebrew/bin/brew shellenv)
end

set fish_greeting ""

if test (uname) = Darwin
    set -g DOTFILES_DIR ~/.dotfiles
else
    set -g DOTFILES_DIR ~/Projects/dotfiles
end

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

# fzf.fish keybindings
fzf_configure_bindings
set fzf_preview_dir_cmd eza --color=always --icons -la
set fzf_preview_file_cmd _fzf_preview_file_cmd
set fzf_diff_highlighter delta --paging=never

# Everblush LS_COLORS — calm palette: only dirs/symlinks/executables get accents
set -x LS_COLORS "di=38;2;141;181;200:ln=38;2;137;181;181:or=38;2;184;138;138:ex=38;2;153;184;152"

# fzf Everblush theme
set -x FZF_DEFAULT_OPTS \
    --cycle --layout=reverse --border=none --height=90% --preview-window=wrap,border-left --marker='*' --scrollbar='█' --input-border --no-separator --info=inline-right \
    --bind='ctrl-/:toggle-preview,ctrl-a:select-all,ctrl-d:deselect-all,ctrl-y:preview-up,ctrl-e:preview-down' \
    --color='fg:#dadada,bg:-1,hl:#67b0e8,fg+:#b3b9b8,bg+:#232a2d,hl+:#6cbfbf,info:#b3b9b8,prompt:#8ccf7e,pointer:#8ccf7e,marker:#8ccf7e,spinner:#e5c76b,header:#67b0e8,border:#2a3538,list-border:#2a3538,scrollbar:#3a4548,separator:#2a3538,gutter:#1e2528'

alias cat="bat --paging=never"
alias tree="eza --tree --color=always --icons --hyperlink"
alias ls="eza --color=always --icons --hyperlink --git"
alias vim="nvim"
if test (uname) = Linux
    alias zed="zeditor"
end
if test (uname) = Linux
    alias bake="sudo nixos-rebuild switch --flake $DOTFILES_DIR/nixos && rcup -K"
    alias yt-dlp="nix run nixpkgs#yt-dlp --"
    alias codex="nix run github:sadjow/codex-cli-nix --"
    alias claude="nix run github:sadjow/claude-code-nix --"
end

abbr --add -- - "cd -"
abbr --add .. "cd .."
abbr --add ... "cd ../.."
abbr --add .... "cd ../../.."
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
abbr --add c "claude --dangerously-skip-permissions"
abbr --add dotc "cd $DOTFILES_DIR && claude --dangerously-skip-permissions"
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
set -x DFT_DISPLAY side-by-side-show-both
set -x MANPAGER "sh -c 'col -bx | bat -l man -p'"

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# macOS-only integrations
if test (uname) = Darwin
    # Added by OrbStack: command-line tools and integration
    # This won't be added again if you remove it.
    source ~/.orbstack/shell/init2.fish 2>/dev/null || :

    # Added by Antigravity
    fish_add_path /Users/aroman/.antigravity/antigravity/bin

    # psql client (libpq is keg-only)
    fish_add_path /opt/homebrew/opt/libpq/bin
end

source "$HOME/.cargo/env.fish" 2>/dev/null

fish_add_path ~/.local/bin

























# bud-wrapper
fish_add_path -g /Users/aroman/.local/bin
function bud
    set -l cd_file (mktemp -t bud-cd.XXXXXX)
    BUD_CD_FILE=$cd_file command '/Users/aroman/Projects/magiccircle-worktrees/ar-bud-improvements-pt6/bud/target/release/bud' $argv
    set -l code $status
    if test -s $cd_file
        cd (cat $cd_file)
    end
    rm -f $cd_file
    return $code
end
# bud-wrapper
