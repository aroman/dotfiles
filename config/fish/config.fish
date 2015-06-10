set -x GOPATH ~/Developer/go
set -x RUST_SRC_PATH ~/Developer/rust/src
set PATH "/usr/local/bin" $PATH
set PATH "/usr/local/heroku/bin" $PATH
set PATH "~/.gem/ruby/2.2.0/bin" $PATH
set PATH "/usr/local/sbin" $PATH
set PATH "/usr/local/share/npm/bin" $PATH
set PATH "$GOPATH/bin" $PATH
alias 'log'="git log --graph --abbrev-commit --decorate --date=relative --format=format:'%C(bold blue)%h%C(reset) - %C(bold green)(%ar)%C(reset) %C(white)%s%C(reset) %C(dim white)- %an%C(reset)%C(bold yellow)%d%C(reset)' --all"

# From http://stackoverflow.com/questions/7064053/add-a-relative-path-to-path-on-fish-startup
if status --is-interactive
    set PATH $PATH ~/Developer/bin
end

eval (python -m virtualfish)
set -x PIP_REQUIRE_VIRTUALENV true

# sanity for 15-122
function r
    ssh unix.andrew.cmu.edu
end

# MacVim stuff
function v
    open -a MacVim $argv
end
set -x EDITOR vim

function c
    xsel --clipboard
end

function pi
    ssh ec2-user@expii.dev
end

function remove-orphans
     pacman -Rns (pacman -Qtdq)
end

set fish_greeting "“There are a thousand hacking at the branches of evil to one who is striking at the root.”"
set fish_greeting "“Things don't have to change the world to be important.”"
set fish_greeting "What if this moment is already perfect?"
