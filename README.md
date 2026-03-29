## Avi's dotfiles

Managed with [rcm](https://github.com/thoughtbot/rcm) (macOS) and [NixOS](https://nixos.org/) + [home-manager](https://github.com/nix-community/home-manager) (Linux).

Most macOS packages are in the [Brewfile](https://github.com/aroman/dotfiles/blob/master/Brewfile). NixOS packages are declared in `nixos/modules/home.nix`.

### What's in here

- **Shell**: fish + starship prompt
- **Terminal**: Ghostty (Everblush theme)
- **Editor**: Zed (primary), Neovim (lazy.nvim), vim (barebones fallback)
- **Git**: difftastic (structural diffs), SSH signing, git-lfs
- **NixOS**: niri compositor, Ptyxis terminal, handlr-regex URL dispatching
- **macOS**: Caps Lock → Escape (hidutil), Touch ID sudo, Dock/Finder defaults

### Non-brew apps (macOS)

- [1Password](https://1password.com/) (not installed via Brew for security reasons)
- [BetterDisplay](https://github.com/waydabber/BetterDisplay)
- [OrbStack](https://orbstack.dev/)

### Setup (macOS)

```bash
# Install rcm and core tools
brew install rcm fish git
brew bundle

# Set fish as default shell
sudo sh -c 'echo $(which fish) >> /etc/shells'
chsh -s $(which fish)

# Install fish plugins
fish -c 'curl -sL https://git.io/fisher | source && fisher install jorgebucaran/fisher && fisher install jorgebucaran/hydro'

# Clone and link dotfiles
git clone git@github.com:aroman/dotfiles.git .dotfiles
rcup

# Build bat theme cache
bat cache --build

# Directories
mkdir -p ~/Projects
mkdir -p ~/Pictures/Screenshots
defaults write com.apple.screencapture location ~/Pictures/Screenshots

# Keyboard
defaults write -g ApplePressAndHoldEnabled -bool false
defaults write -g InitialKeyRepeat -int 15
defaults write -g KeyRepeat -int 2

# Mail
defaults write com.apple.mail AddressesIncludeNameOnPasteboard -bool false

# Appearance
defaults write -g AppleReduceDesktopTinting -bool yes

# Finder
defaults write NSGlobalDomain AppleShowAllExtensions -bool true
chflags nohidden ~/Library
/usr/libexec/PlistBuddy -c "Set :DesktopViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :FK_StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist
/usr/libexec/PlistBuddy -c "Set :StandardViewSettings:IconViewSettings:arrangeBy grid" ~/Library/Preferences/com.apple.finder.plist

# Dock
defaults write com.apple.dock autohide -bool true
defaults write com.apple.dock autohide-delay -float 0
defaults write com.apple.dock persistent-apps -array
defaults write com.apple.dock show-recents -bool false
defaults write com.apple.dock ResetLaunchPad -bool true
defaults write com.apple.dock mineffect -string scale
defaults write com.apple.Dock showhidden -bool true

# Trackpad
defaults write com.apple.AppleMultitouchTrackpad Clicking -bool true

# Velja (disable App Nap so link routing stays fast)
defaults write com.sindresorhus.Velja NSAppSleepDisabled -bool true

# Touch ID for sudo (survives macOS upgrades)
# pam-reattach is needed for tmux sessions; ignore_ssh falls back to password for SSH
# See: https://sixcolors.com/post/2023/08/in-macos-sonoma-touch-id-for-sudo-can-survive-updates/
brew install pam-reattach
printf 'auth       optional       /opt/homebrew/lib/pam/pam_reattach.so ignore_ssh\nauth       sufficient     pam_tid.so\n' | sudo tee /etc/pam.d/sudo_local > /dev/null
```

Reboot to apply everything: `sudo shutdown -r now`

### Setup (NixOS)

#### Bootstrapping a fresh install

On the new machine (fresh NixOS with nothing installed):

```bash
# Get git in a temporary shell
nix-shell -p git

# Clone dotfiles (HTTPS — no SSH keys yet)
mkdir -p ~/Projects
git clone https://github.com/aroman/dotfiles.git ~/Projects/dotfiles

# Copy the auto-generated hardware config into the host directory
mkdir -p ~/Projects/dotfiles/nixos/hosts/<hostname>
cp /etc/nixos/hardware-configuration.nix ~/Projects/dotfiles/nixos/hosts/<hostname>/

# Create default.nix and home.nix for the new host (see existing hosts for reference)
# Then add the host to nixos/flake.nix

# Build and switch
sudo nixos-rebuild switch --flake ~/Projects/dotfiles/nixos#<hostname>
```

After the first rebuild, SSH, git, and everything else from `common.nix` will be available. You can then switch the remote to SSH:

```bash
cd ~/Projects/dotfiles
git remote set-url origin git@github.com:aroman/dotfiles.git
```

#### Existing machine

```bash
git clone git@github.com:aroman/dotfiles.git ~/Projects/dotfiles
sudo nixos-rebuild switch --flake ~/Projects/dotfiles/nixos
rcup -K
```

Hosts are defined in `nixos/hosts/`. Rebuild alias: `bake`

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
- `nixos/modules/home.nix` -- handlr-regex package, `.desktop` entries, TOML config, MIME associations
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

Edit the `handlr.toml` section in `nixos/modules/home.nix`. Rules are matched top-down,
first match wins:

```toml
# Route to a specific Chrome profile
[[handlers]]
exec = "google-chrome-stable --profile-directory=\"Profile 1\" %u"
regexes = ['https?://(www\.)?example\.com(/.*)?']
```

Then rebuild: `bake`
