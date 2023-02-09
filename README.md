## Avi's dotfiles 🤖

Proudly managed with [rcm/thoughtbot](https://github.com/thoughtbot/rcm)!

### Programs

#### Textual 🙈

- brew (macOS)
- wsl-open (WSL)
- git
- jq
- vim
- wget

#### Apps

- 1Password
- Figma
- Spectacle (macOS)
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

### Installation (macOS)

```
brew tap thoughtbot/formulae
brew install rcm vim fish git
brew tap homebrew/cask-fonts
brew install font-hack font-inconsolata font-cascadia-code
sudo sh -c 'echo `which fish` >> /etc/shells'
chsh -s `which fish`
fish
curl -sL https://git.io/fisher | source
git clone git@github.com:aroman/dotfiles.git .dotfiles
rcup

mkdir ~/Projects
mkdir ~/Pictures/Screenshots && defaults write com.apple.screencapture location ~/Pictures/Screenshots
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false
defaults write com.apple.dock persistent-apps -array
killall SystemUIServer && killall Dock
defaults write com.googlecode.iterm2 PrefsCustomFolder -string "~/.dotfiles/iTerm2"
defaults write com.googlecode.iterm2 LoadPrefsFromCustomFolder -bool true
hidutil property --set '{"UserKeyMapping":[{"HIDKeyboardModifierMappingSrc": 0x700000039, "HIDKeyboardModifierMappingDst": 0x700000029}]}'
```
# Finder
```
Showing all filename extensions in Finder by default
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Enable snap-to-grid for icons on the desktop and in other icon views
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Show Library folder in Finder
chflags nohidden ~/Library
```

# Setting Dock to auto-hide and removing the auto-hiding delay

```
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock show-recents -bool false
```

defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

Reset launchpad layout
defaults write com.apple.dock ResetLaunchPad -bool true; killall Dock
defaults write com.apple.dock mineffect -string scale

defaults write com.apple.Dock showhidden -bool true && killall Dock

### Questions? Comments?

Open an issue and I'll get back to you :)
