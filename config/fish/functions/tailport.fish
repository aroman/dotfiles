function tailport --description 'SSH-forward remote port(s) to the same local port'
    # usage: tailport HOST PORT [PORT...]
    #   each PORT may be LOCAL:REMOTE to map across ports (e.g. 8080:80)
    if test (count $argv) -lt 2
        echo "usage: tailport HOST PORT [PORT...]" >&2
        echo "  each PORT may be LOCAL:REMOTE to map across ports (e.g. 8080:80)" >&2
        return 1
    end

    set -l host $argv[1]
    set -l forwards
    for spec in $argv[2..-1]
        # LOCAL[:REMOTE] — REMOTE defaults to LOCAL when no colon is given.
        set -l parts (string split -m1 ':' $spec)
        set -a forwards -L $parts[1]:localhost:$parts[-1]
    end

    echo "Forwarding $host → "(string join ', ' $argv[2..-1])" (Ctrl-C to stop)" >&2
    # ExitOnForwardFailure so a port already in use fails loudly instead of
    # leaving an idle connection that silently forwards nothing.
    ssh -N -o ExitOnForwardFailure=yes $forwards $host
end
