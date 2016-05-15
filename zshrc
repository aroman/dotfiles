# don't share history between instances
SAVEHIST=1000
HISTFILE=~/.zsh_history
unsetopt share_history
unsetopt inc_append_history

# jump between word boundaries on OS X
bindkey '[B' forward-word
bindkey '[F' backward-word

# so i can have nice things
export EDITOR=vim
export AUTOENV_FILE_ENTER=.env
export PATH=~/Developer/bin:$PATH

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

# laziness
type ccat > /dev/null && alias cat="ccat"
alias a="ag -i"
alias k="k -h"
alias ka="k -A"

# numeric file permissions (useful on OS X)
alias numstat='stat -f "%Lp %N"'

# zplug <3
source ~/.zplug/init.zsh

zplug "zsh-users/zsh-syntax-highlighting"
zplug "tarrasch/zsh-autoenv"
zplug "supercrabtree/k"
zplug "peterhurford/up.zsh"
# zplug "b4b4r07/enhancd", use:enhancd.sh
zplug "robbyrussell/oh-my-zsh", \
  use:"lib/{spectrum,git,theme-and-appearance}.zsh", \
  nice:1
zplug "themes/wezm", from:oh-my-zsh, nice:2

if ! zplug check --verbose; then
  zplug install
fi

zplug load
