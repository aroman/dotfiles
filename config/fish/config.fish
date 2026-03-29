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
    abbr --add serve "open 'http://127.0.0.1:8080' && bunx http-server ."
else
    abbr --add serve "xdg-open 'http://127.0.0.1:8080' && bunx http-server ."
end
abbr --add c "claude --dangerously-skip-permissions"
abbr --add dotc "cd $DOTFILES_DIR && claude --dangerously-skip-permissions"
abbr --add yolo "claude --dangerously-skip-permissions"
abbr --add aic ai-commit
abbr --add lg lazygit
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
