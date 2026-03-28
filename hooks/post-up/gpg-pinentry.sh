#!/bin/sh
mkdir -p "$HOME/.gnupg"
# Skip if gpg-agent.conf is managed by home-manager (read-only symlink)
if [ ! -L "$HOME/.gnupg/gpg-agent.conf" ]; then
    echo "pinentry-program $HOME/.local/bin/pinentry-auto" > "$HOME/.gnupg/gpg-agent.conf"
fi
