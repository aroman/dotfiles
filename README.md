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


### Flatpak apps (Linux)

If Zed is installed via Flatpak, symlink the Flatpak config dir to the rcm-managed standard path:
```
ln -sf ~/.config/zed ~/.var/app/dev.zed.Zed/config/zed
```

Zed Flatpak needs `host` filesystem access for file-watching (inotify) to work — without it, files edited externally (e.g. by CLI tools) won't auto-reload in the editor:
```
flatpak override --user dev.zed.Zed --filesystem=host
```

Similarly for Neovim Flatpak:
```
ln -sf ~/.config/nvim ~/.var/app/io.neovim.nvim/config/nvim
flatpak override --user io.neovim.nvim --filesystem=host
```

### Keyboard (Linux)

Remap Caps Lock to Escape system-wide (works in TTY, GDM, and all compositors):
```
localectl set-x11-keymap us "" "" "caps:escape"
```

### URL Dispatching (NixOS / niri)

A domain-based URL routing system that sends links to the right app and Chrome
profile automatically. Think [Velja](https://sindresorhus.com/velja) for Linux.

#### Architecture

```
any app
  -> xdg-open
    -> handlr-regex (registered as default x-scheme-handler/https)
      -> regex match on URL domain
        -> figma.com/*    : figma-open (CDP script)
        -> youtube.com/*  : Chrome (Personal profile)
        -> *              : Chrome (magiccircle.studio profile)
```

**Key files:**
- `nixos/home.nix` -- handlr-regex package, `.desktop` entries, TOML config, MIME associations
- `local/bin/figma-open` -- Figma URL handler script
- `~/.config/handlr/handlr.toml` -- generated regex routing rules

#### How it works

[handlr-regex](https://github.com/Anomalocaridid/handlr-regex) is a Rust-based
`xdg-open` replacement that matches URLs against regex rules. A `.desktop` entry
registers it as the default handler for `x-scheme-handler/http` and
`x-scheme-handler/https`. When any app calls `xdg-open` with an http(s) URL,
handlr matches it against the rules in `handlr.toml` and dispatches to the
appropriate command.

Chrome profiles are selected via `--profile-directory`. Profile names map to
directory names under `~/.config/google-chrome/` (e.g. `Default`, `Profile 1`).

#### Figma deep linking via Chrome DevTools Protocol

`figma-open` goes beyond simple URL dispatching. Figma runs as a Chrome `--app`
window with `--remote-debugging-port=9222`, exposing the
[Chrome DevTools Protocol](https://chromedevtools.github.io/devtools-protocol/).
The script uses CDP over WebSocket (via `websocat`) to control the running Figma
instance:

**Same-file navigation** (e.g. jumping to a different artboard):

When the target URL has the same base path as the currently open file but a
different `node-id` query parameter, the script avoids a full page reload.
Instead, it extracts the node ID and calls Figma's Plugin API directly via
`Runtime.evaluate`:

```javascript
const node = await figma.getNodeByIdAsync('12438:18221');
figma.currentPage.selection = [node];
figma.viewport.scrollAndZoomIntoView([node]);
```

This is the same internal API that Figma plugins use -- it selects the node and
scrolls the viewport to it instantly, with no reload.

**Different-file navigation:**

Uses CDP `Page.navigate` for a standard full navigation to the new file.

**Figma not running:**

Falls back to launching Chrome with the full `--app`, `--user-data-dir`,
`--user-agent`, and `--remote-debugging-port` flags.

**Window focus:**

After navigation, the script focuses the Figma window via
[niri](https://github.com/YaLTeR/niri)'s IPC (`niri msg action focus-window`),
matching on the `app_id` prefix `chrome-www.figma.com`.

#### Adding a new domain rule

Edit the `handlr.toml` section in `nixos/home.nix`. Rules are matched top-down,
first match wins:

```toml
# Route to a specific Chrome profile
[[handlers]]
exec = "google-chrome-stable --profile-directory=\"Profile 1\" %u"
regexes = ['https?://(www\.)?example\.com(/.*)?']
```

Then rebuild: `sudo nixos-rebuild switch --flake ./nixos#wizardtower`

### Questions? Comments?

Open an issue and I'll get back to you :)
