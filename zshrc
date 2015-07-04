#
# Executes commands at the start of an interactive session.
#
# Authors:
#   Sorin Ionescu <sorin.ionescu@gmail.com>
#

# Source Prezto.
if [[ -s "${ZDOTDIR:-$HOME}/.zprezto/init.zsh" ]]; then
  source "${ZDOTDIR:-$HOME}/.zprezto/init.zsh"
fi

export EDITOR=vim
export AUTOENV_FILE_ENTER=.env

# Git
alias g="git"
alias gs="git status"
alias gc="git commit"

# Expii
alias prod="ssh -i ~/expii-general.pem ubuntu@10.0.25.103"
alias stage="ssh -i ~/expii-general.pem ubuntu@10.0.31.238"
alias a="ag -s --ignore app.js* --ignore vendor.js* --ignore-dir flatfiles --ignore-dir external --ignore skydeity.min.js --ignore geo_data.txt"
[ -f /usr/local/share/zsh/site-functions/_aws ] && source /usr/local/share/zsh/site-functions/_aws
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh
