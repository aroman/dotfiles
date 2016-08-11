## Avi's dotfiles 🤖
Proudly managed with [rcm/thoughtbot](https://github.com/thoughtbot/rcm)!

### Programs

#### Textual 🙈
- zsh + zplug
- vim + vim-plug
- the_silver_searcher
- brew
- git
- ccat
- fpp
- jq
- wget
- ngrok

#### Graphical 👀
- Sketch
- Spotify
- Google Chrome
- Slack
- Atom
- Etcher
- Viscosity

### Directories
`~/Developer`
`~/Pictures/Screenshots`

### Installation (OS X)

```
$ brew tap thoughtbot/formulae
$ brew install rcm vim zsh zplug the_silver_searcher git
$ command -v zsh | sudo tee -a /etc/shells
$ chsh -s $(command -v zsh)
$ zsh
$ git clone git@github.com:aroman/dotfiles ~/.dotfiles
$ rcup
$ mkdir ~/Pictures/Screenshots && defaults write com.apple.screencapture location ~/Pictures/Screenshots && killall SystemUIServer
```

### Questions? Comments?

Open an issue and I'll get back to you :)
