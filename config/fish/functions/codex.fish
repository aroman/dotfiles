function codex --wraps codex --description 'Run codex tagged so herdr detects it in the agents panel'
    # herdr identifies agents by their foreground process name. The Nix
    # codex-cli-nix package is a wrapper that execs `codex-raw`, so herdr never
    # sees a process called "codex" and leaves the pane out of the agents panel
    # (claude-code-nix keeps argv[0]="claude", which is why claude shows up).
    # HERDR_AGENT is herdr's explicit hint for agents hidden behind wrappers.
    set -lx HERDR_AGENT codex
    command codex $argv
end
