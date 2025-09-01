# vim: set ts=4

if status --is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end

set fish_greeting ""
starship init fish | source

alias cat="bat --paging=never"

# abbr --add pi "ssh carovi@raspberrypi.local"
# abbr --add godo "godot *.godot &> /dev/null &"
abbr --add wrangler "pnpm wrangler"
abbr --add a "ag -i"
# abbr --add hack "code ."
abbr --add hack "cursor ."
abbr --add exifscrub "exiftool -all= "
abbr --add gg "cd ~/Projects/magiccircle.gg"
abbr --add serve "open 'http://127.0.0.1:8080' && bunx http-server ."

abbr --add gs "git status"
abbr --add gl "git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit"

switch (uname -r)
	case '*microsof*'
		abbr --add open "wsl-open"
	case '*darwin*'
		abbr --add foo "bar"
end

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

# # LLVM symbolizer
# set -x LLVM_SYMBOLIZER /opt/homebrew/opt/llvm/bin/llvm-symbolizer

# GPG Key Setup
set -x GPG_TTY (tty)

# set theme to Solarized Dark
set -U fish_color_normal normal
set -U fish_color_command 93a1a1
set -U fish_color_quote 657b83
set -U fish_color_redirection 6c71c4
set -U fish_color_end 268bd2
set -U fish_color_error dc322f
set -U fish_color_param 839496
set -U fish_color_comment 586e75
set -U fish_color_match --background=brblue
set -U fish_color_selection white --bold --background=brblack
set -U fish_color_search_match bryellow --background=black
set -U fish_color_history_current --bold
set -U fish_color_operator 00a6b2
set -U fish_color_escape 00a6b2
set -U fish_color_cwd green
set -U fish_color_cwd_root red
set -U fish_color_valid_path --underline
set -U fish_color_autosuggestion 586e75
set -U fish_color_user brgreen
set -U fish_color_host normal
set -U fish_color_cancel -r
set -U fish_pager_color_completion B3A06D
set -U fish_pager_color_description B3A06D
set -U fish_pager_color_prefix cyan --underline
set -U fish_pager_color_progress brwhite --background=cyan

# bun
set --export BUN_INSTALL "$HOME/.bun"
set --export PATH $BUN_INSTALL/bin $PATH

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init2.fish 2>/dev/null || :

alias claude="/Users/aroman/.claude/local/claude"

test -e {$HOME}/.iterm2_shell_integration.fish ; and source {$HOME}/.iterm2_shell_integration.fish ; or true

