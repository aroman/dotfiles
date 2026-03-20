#!/usr/bin/env bash
# Sets terminal tab title + bell when Claude Code needs attention.
# Works on any terminal that supports OSC 2 (tab title) and BEL — which
# is virtually all modern terminals (Ghostty, ptyxis, kitty, alacritty,
# WezTerm, GNOME Terminal, Konsole, iTerm2, etc.)
#
# On idle/permission: sets tab title with emoji + session name/cwd + sends bell
# On user prompt submit: clears the indicator

input=$(cat)

# Find the TTY from the parent claude process (hook subprocess has no /dev/tty)
tty_dev="/dev/$(ps -o tty= -p "$PPID" 2>/dev/null | tr -d ' ')"
[[ -w "$tty_dev" ]] || exit 0

# Parse JSON — pipe delimiter preserves empty fields (bash read collapses tabs)
IFS='|' read -r event notification_type cwd < <(echo "$input" | jq -r '[(.hook_event_name // ""), (.notification_type // ""), (.cwd // "")] | join("|")')

# Try to extract --name from parent claude process args
name=$(ps -o args= -p "$PPID" 2>/dev/null | sed -n 's/.*--name  *\([^ ]*\).*/\1/p')

# Fall back to shortened cwd
if [[ -z "$name" ]]; then
  name="${cwd/#$HOME/~}"
fi

case "$event" in
  Notification)
    # notification_type may be missing (claude-code#11964) — default to generic indicator
    case "$notification_type" in
      permission_prompt)
        printf '\033]2;✋ %s\a\a' "$name" > "$tty_dev"
        ;;
      *)
        printf '\033]2;💬 %s\a\a' "$name" > "$tty_dev"
        ;;
    esac
    ;;
  UserPromptSubmit)
    # Reset tab title — shell/starship will take over
    printf '\033]2;\033\\' > "$tty_dev"
    ;;
esac

exit 0
