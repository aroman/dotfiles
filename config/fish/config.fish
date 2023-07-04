if status --is-interactive
  eval (/opt/homebrew/bin/brew shellenv)
end

set fish_greeting ""

function godo
  godot *.godot &> /dev/null &
end

alias gs="git status"
alias a="ag -i"
alias hack="code ."
alias exifscrub="exiftool -all= "
alias brew='sudo -Hu aroman brew'
alias cat='bat --paging=never'

switch (uname -r)
	case '*microsof*'
		alias open='wsl-open'
end

function gl
	git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
end

# GPG Key Setup
set -x GPG_TTY (tty)

set -Ux LS_COLORS "$LS_COLORS:ow=1;34:tw=1;34:"

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
