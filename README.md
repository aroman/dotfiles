## Avi's dotfiles 🤖
Proudly managed with [rcm/thoughtbot](https://github.com/thoughtbot/rcm)!

### Programs

#### Textual 🙈
- brew
- git
- jq
- ngrok
- vim
- wget

#### Graphical 👀
- 1Password
- Etcher
- Google Chrome
- Sketch
- Spectacle
- Spotify
- VSCode

### Directories
`~/Projects`
`~/Pictures/Screenshots`

### Installation (elementary OS)
```
wget -qO - https://apt.thoughtbot.com/thoughtbot.gpg.key | sudo apt-key add -
echo "deb http://apt.thoughtbot.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thoughtbot.list
sudo apt update
sudo apt install rcm git fish fonts-ttf-hack
chsh -s $(which fish)
fish
git clone git@github.com:aroman/dotfiles.git .dotfiles
rcup
```

### Installation (macOS)

```
$ brew tap thoughtbot/formulae
$ brew install rcm vim fish git
$ brew tap caskroom/fonts
$ brew cask install font-inconsolata
$ command -v zsh | sudo tee -a /usr/local/bin/fish
$ chsh -s /usr/local/bin/fish
$ fish
$ git clone git@github.com:aroman/dotfiles.git .dotfiles
$ rcup

$ mkdir ~/Projects
$ mkdir ~/Pictures/Screenshots && defaults write com.apple.screencapture location ~/Pictures/Screenshots
$ defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
$ defaults write com.apple.dock persistent-apps -array
$ killall SystemUIServer && killall Dock
```

### Questions? Comments?

Open an issue and I'll get back to you :)
