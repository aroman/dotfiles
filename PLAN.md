# NixOS Migration Plan

## Overview

Migrate from Fedora Silverblue to NixOS on Framework 13 AMD. Keep the dotfiles repo
cross-platform (macOS + NixOS). Use Flakes + Home Manager with `mkOutOfStoreSymlink`
to link existing raw config files (KDL, JSON, Lua) — no need to rewrite them as Nix expressions.

## Repo Structure

Add a `nixos/` directory alongside existing dotfiles:

```
~/.dotfiles/
├── nixos/                          # NEW
│   ├── flake.nix                   # Flake inputs & outputs
│   ├── configuration.nix           # System-level config
│   └── home.nix                    # Home Manager (user packages + symlinks)
├── config/                         # UNCHANGED — raw configs stay as-is
│   ├── niri/config.kdl
│   ├── nvim/init.lua
│   ├── zed/{settings.json,keymap.json}
│   ├── fish/{config.fish,fish_plugins,functions/}
│   ├── bat/config
│   └── environment.d/editor.conf
├── gitconfig                       # UNCHANGED
├── local/bin/pinentry-auto         # UNCHANGED
├── vim/                            # UNCHANGED
├── Brewfile                        # UNCHANGED (macOS)
└── ...
```

## Step 1: Create `nixos/flake.nix`

Flake inputs:
- `nixpkgs` (nixos-unstable)
- `home-manager` (follows nixpkgs)
- `nixos-hardware` (framework-13-7040-amd)
- `niri-flake` (sodiboo/niri-flake — provides niri + portal + polkit setup)

Single output: `nixosConfigurations.framework`

## Step 2: Create `nixos/configuration.nix`

System-level declarations:

- **Boot**: systemd-boot (simpler than GRUB on NixOS, avoids the composefs mess you had)
- **Networking**: NetworkManager, hostname
- **Locale**: en_US.UTF-8, US timezone
- **Users**: `aroman`, shell = fish, wheel group
- **Niri**: `programs.niri.enable = true` (via niri-flake, handles portals/polkit)
- **Audio**: PipeWire + WirePlumber (replaces the Flatpak EasyEffects hack)
- **Fonts**: Cascadia Code NF, Noto, emoji fonts
- **Keyboard**: `services.xserver.xkb.options = "caps:escape"`
- **Firmware**: fwupd enabled (Framework updates)
- **GPG**: gnupg + pinentry-gnome3
- **Display manager**: greetd with tuigreet (lightweight, no GDM)
- **Security**: polkit (for 1Password, etc.)
- **System packages**: Core CLI tools only (git, vim, etc.)
- **OpenGL/Vulkan**: hardware.graphics.enable (replaces the codec fiasco)
- **Flatpak**: Optionally keep for apps not in nixpkgs (if any)

## Step 3: Create `nixos/home.nix`

Home Manager config using `mkOutOfStoreSymlink` to link existing dotfiles:

**Symlinks** (all via `xdg.configFile."...".source = mkOutOfStoreSymlink`):
- `niri/config.kdl` → `~/.dotfiles/config/niri/config.kdl`
- `nvim` → `~/.dotfiles/config/nvim`
- `zed` → `~/.dotfiles/config/zed`
- `fish` → `~/.dotfiles/config/fish`
- `bat` → `~/.dotfiles/config/bat`
- `environment.d` → `~/.dotfiles/config/environment.d`

**Home files** (via `home.file`):
- `.gitconfig` → `~/.dotfiles/gitconfig`
- `.gitignore_global` → `~/.dotfiles/gitignore_global`
- `.vim` → `~/.dotfiles/vim`
- `.ssh/config` → `~/.dotfiles/ssh/config`
- `.local/bin/pinentry-auto` → `~/.dotfiles/local/bin/pinentry-auto`

**User packages** (stuff that was rpm-ostree/flatpak/distrobox):
- neovim, bat, fzf, ripgrep, fd, jq, gh, starship
- playerctl, brightnessctl, wl-clipboard
- swaylock, fuzzel
- firefox, chromium (or google-chrome)
- spotify, vesktop (Discord)
- 1password-gui
- easyeffects (native — no more Flatpak wrapper!)
- zed-editor
- ptyxis (or foot/alacritty as terminal)
- vicinae, qs/noctalia-shell (if in nixpkgs, otherwise custom package)

**Shell**: `programs.fish.enable = true` (just to ensure fish is in /etc/shells,
actual config comes from the symlinked dotfile)

**GPG agent**: `services.gpg-agent` with pinentry-gnome3

## Step 4: Niri Config Updates

Your existing `config/niri/config.kdl` needs minor tweaks for NixOS:
- Remove `flatpak run` wrappers from `spawn-at-startup` (EasyEffects runs natively)
- Update terminal spawn if switching from BlackBox Flatpak
- Remove `flatpak run` from Zed alias in fish config
- The vicinae/qs spawns stay if those are available as packages

## Step 5: Fish Config Updates

Minor edits to `config/fish/config.fish`:
- Remove/guard the `brew shellenv` block (already guarded with `uname = Darwin`)
- Remove `alias zed="flatpak run dev.zed.Zed"` (Zed will be in PATH natively)
- Remove Spicetify path addition
- The rest (aliases, abbreviations, colors, GPG_TTY) works as-is

## Step 6: Clean Up Silverblue-Specific Files

Remove or guard behind platform checks:
- `hooks/post-up/flatpak-zed.sh` — not needed (no Flatpak Zed)
- `hooks/post-up/gnome-darkmode.sh` — replace with NixOS declarative config or keep for macOS
- `hooks/post-up/vim-plug.sh` — keep (vim still uses vim-plug)
- `bin/start-browser.sh` — likely obsolete
- `config/environment.d/editor.conf` — can set EDITOR in NixOS config instead

## Step 7: Installation

1. Download NixOS minimal ISO (unstable channel)
2. Boot from USB on Framework 13
3. Partition disk (UEFI: ESP + root, optionally encrypted with LUKS)
4. Run `nixos-generate-config` to get `hardware-configuration.nix`
5. Clone dotfiles repo, copy generated hardware-configuration.nix into `nixos/`
6. Run `nixos-install --flake .dotfiles/nixos#framework`
7. Reboot, login, run `home-manager switch` (or it runs as part of nixos-rebuild)

## What Gets Better

| Silverblue pain point | NixOS solution |
|---|---|
| "flatpak or rpm-ostree or distrobox?" | Everything is `nix` |
| Flatpak sandbox punching (inotify, clipboard) | Native packages, no sandbox |
| rpm-ostree reboot for every package | `nixos-rebuild switch`, instant |
| Codec conflicts (noopenh264 fiasco) | `hardware.graphics.enable = true` |
| GRUB broken on composefs | systemd-boot just works |
| EasyEffects Flatpak autostart hack | `services.easyeffects.enable` or native spawn |
| pinentry-gnome3 "already provided" but missing | `programs.gnupg.agent.pinentryPackage` |
| distrobox for AUR packages | nixpkgs has 100k+ packages |

## What Stays the Same

- All your config files (KDL, JSON, Lua, fish) — unchanged
- Your dotfiles repo structure — still works with rcm on macOS
- Git workflow — still a git repo, still `rcup` on macOS
- Keybinds, themes, scroll tuning — all in your existing configs
