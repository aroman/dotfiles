# Setup fzf
if [[ "$OSTYPE" == "linux-gnu" ]]; then
  if [[ ! "$PATH" =~ "/home/avi/.fzf/bin" ]]; then
    export PATH="$PATH:/home/avi/.fzf/bin"
    export MANPATH="$MANPATH:/home/avi/.fzf/man"
    [[ $- =~ i ]] && source "/home/avi/.fzf/shell/completion.zsh" 2> /dev/null
    source "/home/avi/.fzf/shell/key-bindings.zsh"
  fi
elif [[ "$OSTYPE" == "darwin"* ]]; then
  if [[ ! "$PATH" =~ "/usr/local/Cellar/fzf/0.10.0/bin" ]]; then
    export PATH="$PATH:/usr/local/Cellar/fzf/0.10.0/bin"
    export MANPATH="$MANPATH:/usr/local/Cellar/fzf/0.10.0/man"
    [[ $- =~ i ]] && source "/usr/local/Cellar/fzf/0.10.0/shell/completion.zsh" 2> /dev/null
    source "/usr/local/Cellar/fzf/0.10.0/shell/key-bindings.zsh"
  fi
fi
