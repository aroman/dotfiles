set fish_greeting ""

alias gs="git status"
alias a="ag -i"
alias hack="code ."
alias exifscrub="exiftool -all= "

function gl
	git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold blue)<%an>%Creset' --abbrev-commit
end
