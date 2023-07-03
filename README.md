## Avi's dotfiles 🤖

Proudly managed with [rcm/thoughtbot](https://github.com/thoughtbot/rcm)!

#### Most things installed via Brew, check out the [Brewfile](https://github.com/aroman/dotfiles/blob/master/Brewfile)!

### Non-brew apps

#### Must-have
- 1Password (For security reasons, not installed via Brew)
- [BetterDisplay](https://github.com/waydabber/BetterDisplay) (Not available via Brew)
- [Cursor](https://www.cursor.so/) (Too unstable for Brew)
- ExpressVPN (For security reasons, not installed via Brew)
- [Screen Studio](https://www.screen.studio/download)

#### Sometimes useful
- [NearDrop](https://github.com/grishka/NearDrop) (Not available via Brew)
- [Opal Camera](https://opalcamera.com/)
- [PingPlotter](https://formulae.brew.sh/cask/pingplotter#default)
- [qFlipper](https://formulae.brew.sh/cask/qflipper#default)
- [Kinesis SmartSet](https://kinesis-ergo.com/download-category/smartset-app/)

### Installation (macOS)

```
brew tap thoughtbot/formulae
brew install rcm vim fish git
brew tap homebrew/cask-fonts
brew install font-hack font-inconsolata font-cascadia-code
sudo sh -c 'echo `which fish` >> /etc/shells'
chsh -s `which fish`
fish
curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher && fisher install jorgebucaran/hydro
git clone git@github.com:aroman/dotfiles.git .dotfiles
rcup

mkdir ~/Projects
mkdir ~/Pictures/Screenshots && defaults write com.apple.screencapture location ~/Pictures/Screenshots
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2
defaults write -g AppleReduceDesktopTinting -bool yes
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/.dotfiles/iTerm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true

# Finder
Showing all filename extensions in Finder by default
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Show Library folder in Finder
chflags nohidden ~/Library

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock ResetLaunchPad -bool true
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.Dock showhidden -bool true

# Enable tap-to-click
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true
```

Finally... reboot to apply everything
```
sudo shutdown -r now
```


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

### Installation (WSL2)

- Install Windows Terminal
- Install [Cascadia Code](https://github.com/microsoft/cascadia-code/releases)

```
wget -qO - https://apt.thoughtbot.com/thoughtbot.gpg.key | sudo apt-key add -
echo "deb http://apt.thoughtbot.com/debian/ stable main" | sudo tee /etc/apt/sources.list.d/thoughtbot.list
sudo apt update
sudo apt install rcm git fish
sudo npm install -g wsl-open
chsh -s $(which fish)
fish
git clone git@github.com:aroman/dotfiles.git .dotfiles
rcup
```


### Questions? Comments?

Open an issue and I'll get back to you :)
