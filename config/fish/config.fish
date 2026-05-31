# vim: set ts=4

set -gx LG_CONFIG_FILE ~/.config/lazygit/config.yml

function cat --wraps bat --description "bat with image support"
    # If single file arg and it's an image, display it
    if test (count $argv) -eq 1 -a -f "$argv[1]"
        set -l mime (command file --brief --dereference --mime -- "$argv[1]")
        if string match -q "image/*" -- $mime
            if set -q KITTY_WINDOW_ID; or set -q GHOSTTY_RESOURCES_DIR; and command -q kitten
                kitten icat --align=left "$argv[1]"
            else if command -q chafa
                chafa "$argv[1]"
            else
                command file "$argv[1]"
            end
            return
        end
    end
    bat --paging=never $argv
end
alias tree="eza --tree --color=always --icons --hyperlink"
alias ls="eza --color=always --icons --hyperlink --git"
alias vim="nvim"

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
    set -gx ANDROID_HOME "$HOME/Library/Android/sdk"
    abbr --add serve "open 'http://127.0.0.1:8080' && bunx http-server ."
else
    set -gx ANDROID_HOME "$HOME/Android/Sdk"
    abbr --add serve "xdg-open 'http://127.0.0.1:8080' && bunx http-server ."
end
fish_add_path $ANDROID_HOME/platform-tools
fish_add_path $ANDROID_HOME/emulator
abbr --add c "claude --dangerously-skip-permissions"
abbr --add cr "claude --dangerously-skip-permissions --resume"
abbr --add x "codex --yolo"
# `xr` is a function (config/fish/functions/xr.fish): codex resume, but auto-opens
# the session when it is the only one recorded for the current directory.
abbr --add dotc "cd $DOTFILES_DIR && claude --dangerously-skip-permissions"
abbr --add dr "cd $DOTFILES_DIR && claude --dangerously-skip-permissions --resume"
# `bp` sends clipboard contents to `bud new -p` as a single argument — sidesteps
# quote escaping for prompts with mixed single+double quotes. See bpe (function)
# for the editor-based variant when you want to compose/edit first.
abbr --add bp 'bud new -p "$(wl-paste)"'
abbr --add aic ai-commit
abbr --add lg lazygit
abbr --add gp "git push"
abbr --add gpf "git push --force-with-lease"
abbr --add gs "git status"
abbr --add gd "git diff"
abbr --add gl "git log --graph --pretty=format:'%C(bold blue)%h%C(reset)%C(bold yellow)%d%C(reset) %s%n         %C(dim cyan)%an%C(reset) %C(dim)• %cr%C(reset)' --abbrev-commit"

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
