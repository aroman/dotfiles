# prezto
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

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
alias a="ag -i --ignore 'expii/leaderboard/'"

# numeric file permissions on OS X
alias numstat='stat -f "%Lp %N"'

alias coin="rlwrap coin"

[ -f /usr/local/share/zsh/site-functions/_aws ] && source /usr/local/share/zsh/site-functions/_aws
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
