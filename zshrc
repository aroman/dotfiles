# don't share history between instances
unsetopt share_history
unsetopt inc_append_history

# jump between word boundaries on OS X
bindkey "^[f" forward-word
bindkey "^[b" backward-word

# so i can have nice things
export EDITOR=vim
export AUTOENV_FILE_ENTER=.env
export PATH=~/Developer/bin:$PATH
export FPP_EDITOR=$EDITOR

# go
export GOPATH=~/Developer/go
export PATH=$PATH:$GOPATH/bin
export PATH=$PATH:/usr/local/opt/go/libexec/bin

# git
alias g="git"
alias gs="git status"
alias gd="git diff"
alias gc="git commit"
alias gch="git checkout"
alias gcb="git rev-parse --abbrev-ref HEAD"
alias gpsu="git push --set-upstream origin \`gcb\`"

# swag
type ccat > /dev/null && alias cat="ccat"
alias a="ag -i"

# numeric file permissions on OS X
alias numstat='stat -f "%Lp %N"'

[ -f /usr/local/share/zsh/site-functions/_aws ] && source /usr/local/share/zsh/site-functions/_aws
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

source "${HOME}/.zgen/zgen.zsh"

# if the init scipt doesn't exist
if ! zgen saved; then

	zgen prezto environment
  zgen prezto editor key-bindings 'vi'
 	zgen prezto prompt theme 'sorin'
	# zgen prezto '*:*' case-sensitive 'yes'
	zgen prezto '*:*' color 'yes'

	zgen prezto
  zgen prezto git
	# zgen prezto utility
	# zgen prezto completion
	zgen prezto syntax-highlighting
	# zgen prezto history-substring-search

  zgen load Tarrasch/zsh-autoenv

  # generate the init script from plugins above
  zgen save
fi
