#!/bin/sh
mkdir -p "$HOME/.gnupg"
echo "pinentry-program $HOME/.local/bin/pinentry-auto" > "$HOME/.gnupg/gpg-agent.conf"
