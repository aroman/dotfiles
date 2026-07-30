function _tailport_open --description 'Open forwarded URLs once ssh has bound them'
    # Own file so tailport can autoload and background it as a real process (see
    # its comment there). Matched below as SendEnv=$tag, never bare $tag — our own
    # argv carries the tag, and a bare match would find this very process.
    set -l tag $argv[1]
    set -l urls $argv[2..-1]

    # Same Darwin split as the `serve` abbr in config.fish. Deliberately not
    # `command -q open`, which false-positives on util-linux's unrelated `open`.
    set -l opener xdg-open
    if test (uname) = Darwin
        set opener open
    end

    # Without lsof we cannot tell whose listener is whose, so open blind after a
    # beat. Both machines ship it (killport uses it too) — this is just a backstop.
    if not command -q lsof
        sleep 1
        for url in $urls
            $opener $url
        end
        return
    end

    # tailport forks us just before launching ssh; until it shows up, a listener
    # here cannot be ours — it would be a retry's, or something unrelated.
    set -l ssh_pid
    for i in (seq 50)
        set ssh_pid (pgrep -f "SendEnv=$tag" | head -1)
        test -n "$ssh_pid"; and break
        sleep 0.1
    end
    test -n "$ssh_pid"; or return

    for url in $urls
        set -l port (string match -rg ':(\d+)$' $url)
        # A host-key prompt, passphrase or MFA push can block ssh long before it
        # binds anything, so probe for about a minute — and require the listener to
        # be *ours*, since anything else answering by now belongs to someone else.
        set -l up 0
        for i in (seq 120)
            if contains -- $ssh_pid (lsof -nP -iTCP:$port -sTCP:LISTEN -t 2>/dev/null)
                set up 1
                break
            end
            # Bail if ssh died (Ctrl-C, refused forward, failed auth), else we would
            # linger and could latch onto a retry's listener. Ctrl-C aborts the rest
            # of tailport, so this is the only thing that stops us.
            kill -0 $ssh_pid 2>/dev/null; or return
            sleep 0.5
        end
        # ExitOnForwardFailure means ssh bound every -L or none, so a port that
        # never became ours means the connection failed outright — the remaining
        # ones will not show up either.
        test $up -eq 1; or return
        # One call per URL: xdg-open only ever looks at its first argument.
        $opener $url
    end
end
