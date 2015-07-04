# prezto
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

# so i can have nice things
export EDITOR=vim
export AUTOENV_FILE_ENTER=.env
export PATH=~/Developer/bin:$PATH

# git
alias g="git"
alias gs="git status"
alias gc="git commit"

# swag
type ccat > /dev/null && alias cat="ccat"
alias a="ag -i"

# expii
alias prod="ssh -i ~/expii-general.pem ubuntu@10.0.25.103"
alias stage="ssh -i ~/expii-general.pem ubuntu@10.0.31.238"
[ -f /usr/local/share/zsh/site-functions/_aws ] && source /usr/local/share/zsh/site-functions/_aws
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
