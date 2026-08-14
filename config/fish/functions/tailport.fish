function tailport --description 'SSH-forward remote port(s) to the same local port, opening each in a browser'
    # usage: tailport HOST PORT [PORT...]
    #   each PORT may be LOCAL:REMOTE to map across ports (e.g. 8080:80)
    #   each forwarded port is opened in a browser once it accepts connections
    if test (count $argv) -lt 2
        echo "usage: tailport HOST PORT [PORT...]" >&2
        echo "  each PORT may be LOCAL:REMOTE to map across ports (e.g. 8080:80)" >&2
        return 1
    end

    set -l host $argv[1]
    set -l forwards
    set -l urls
    for spec in $argv[2..-1]
        # LOCAL[:REMOTE] — REMOTE defaults to LOCAL when no colon is given.
        set -l parts (string split -m1 ':' $spec)
        # ssh takes /etc/services names as well as numbers, but the URL needs a
        # number. Aliases count: macOS lists `http 80/tcp www www-http` and ssh
        # accepts `www`. ssh rejects unknown names too, so erroring here loses
        # nothing that would otherwise have worked.
        set -l lport $parts[1]
        if not string match -qr '^\d+$' $lport
            # Field 1 is the name, 2 the port, 3+ aliases — once the comment is gone.
            set lport (awk -v n=$lport '
                    $2 ~ /\/tcp$/ {
                        sub(/#.*/, "")
                        for (i = 1; i <= NF; i++) {
                            if (i != 2 && $i == n) { split($2, a, "/"); print a[1]; exit }
                        }
                    }
                ' /etc/services)
            if test -z "$lport"
                echo "tailport: '$parts[1]' is not a port number or a known service name" >&2
                return 1
            end
        end
        # No pre-flight "port free?" check: ssh (ExitOnForwardFailure) is the judge,
        # and the opener only trusts a listener it can attribute to that ssh — so
        # nothing here depends on knowing the port was free beforehand.
        set -a forwards -L $lport:localhost:$parts[-1]
        # https when the far side is TLS, else the browser speaks plaintext at it.
        set -l scheme (contains -- $parts[-1] 443 https; and echo https; or echo http)
        set -a urls $scheme://localhost:$lport
    end

    echo "Forwarding $host → "(string join ', ' $argv[2..-1])" (Ctrl-C to stop)" >&2
    for url in $urls
        echo "  $url" >&2
    end

    # Stamps this one ssh invocation so the opener can recognise it and nothing
    # else — notably not the ssh of an immediate retry on the same port. SendEnv
    # names a variable that does not exist, so nothing is actually sent; it is here
    # only because it lands the tag in ssh's argv, where pgrep can match it.
    set -l tag TAILPORT_(random)_$fish_pid

    # Only open where localhost is this machine. Over ssh, the xdg-open shim in
    # nixos/modules/home.nix pipes URLs back through the forwarded ~/.opener.sock
    # (ssh/config) to the Mac, which would resolve localhost against its own
    # loopback — the wrong host, maybe with something unrelated on that port.
    if set -q SSH_CONNECTION
        echo "  (ssh session — reachable only on "(hostname -s)", so not opening)" >&2
    else
        # ssh -N blocks, so probe and open in the background — as an external
        # command, since fish runs a backgrounded *function* synchronously and
        # would stall ssh. _tailport_open lives in its own file so a fresh fish
        # autoloads it; passing $urls as argv (not text to re-split) keeps what we
        # open in sync with what we printed.
        fish -c '_tailport_open $argv' $tag $urls &
    end

    # ExitOnForwardFailure so a port already in use fails loudly instead of
    # leaving an idle connection that silently forwards nothing.
    #
    # ControlPath=none opts out of the multiplexing in ssh/config. Otherwise this
    # ssh becomes the ControlMaster, and ControlPersist backgrounds it the moment
    # -N leaves it with nothing to do: the forward survives without us, we return
    # to the prompt immediately, Ctrl-C stops nothing, and the leftover listener
    # makes the next tailport report the port as already in use.
    ssh -N -o ExitOnForwardFailure=yes -o ControlPath=none -o SendEnv=$tag $forwards $host
end
