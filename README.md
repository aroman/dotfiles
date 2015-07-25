# Avi's dotfiles (documentation WIP)
## Using [rcm](https://github.com/thoughtbot/rcm)

### Command-line tools

git
ccat
awscli
fpp
fzf
jq
nmap
the_silver_searcher
rcm
xz
wget
zsh
vim
unrar
node/npm
ngrok

### Graphical Programs
Sketch
Spotify
Google Chrome
Slack
Simplenote
Atom
Reeder
Viscosity
sdaitzman/elementary-thumbdrive-creator (http://cl.ly/3e1q262Q2M1r/download/Make%20Elementary%20Thumb%20Drive.app.zip)

`git clone --recursive https://github.com/sorin-ionescu/prezto.git "${ZDOTDIR:-$HOME}/.zprezto"`

```
setopt EXTENDED_GLOB
for rcfile in "${ZDOTDIR:-$HOME}"/.zprezto/runcoms/^README.md(.N); do
  ln -s "$rcfile" "${ZDOTDIR:-$HOME}/.${rcfile:t}"
done
```

### Home directory structure
~/Developer
~/Pictures/Screenshots

### OS X Setup

```
$ brew tap thoughtbot/formulae
$ brew install rcm
```

### Atom packages
```apm install atom-jinj2 language-jsx language-nginx language-pegjs language-rust react sort-lines vim-mode``

