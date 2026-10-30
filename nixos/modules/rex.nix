{ inputs, username, ... }:

# Rex login server — keeps Rex reachable from other tailnet devices (Rex for
# Mac) without anyone first running `rex` on this host.
#
# Without it, Rex only runs on demand: any `rex` command spawns a personal
# server on /run/user/<uid>/rex/server.sock that exits ~10 s after its last
# session closes, and it listens on nothing but that Unix socket.
#
# The login server is a root unit. It identifies each tailnet caller through
# tailscaled, maps them to an OS account via /etc/rex/accounts.jsonc, and starts
# or reuses that account's personal server — the same one local `rex` commands
# use, so local and remote clients see the same sessions. Restarting the login
# server (e.g. on a Rex bump) leaves account servers and their sessions running.
# Someone who reaches the host only over SSH can still run `rex` there and share
# those sessions; only remote Rex clients need to be on the tailnet.
#
# Tailscale Serve forwards https://<host>.<tailnet>.ts.net:7297 to it. The
# module's default port is kept because Serve's 443 may already be taken
# (wizardtower proxies a dev server there); give clients the :7297 address
# explicitly so they don't land on that first.
#
# Only hosts that import this file run it. pkgs.superlogical.com needs the
# pre-release token in /etc/nix/netrc on whichever machine evaluates and builds
# the system — the deploying machine, for a --target-host deploy.
{
  imports = [ inputs.rex.nixosModules.default ];

  services.rex.loginServer = {
    enable = true;
    tailscaleServe.enable = true;
    # Mirrors operator-authorized-keys.nix: the operator can always act as the
    # host's primary user. A host whose user is someone else (a cloud devbox's
    # developer) appends their Tailscale login to this same list.
    #
    # Never `tailscale:*`: other people's devices share this tailnet, and a Rex
    # connection can run anything as the account.
    accounts.${username}.principals = [ "tailscale:aroman@github" ];
  };
}
