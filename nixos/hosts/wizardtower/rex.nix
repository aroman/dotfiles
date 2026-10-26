{ inputs, username, ... }:

# Rex login server — keeps Rex reachable from other tailnet devices (Rex for
# Mac on dawnbinder) without anyone first running `rex` on this host.
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
#
# Tailscale Serve forwards https://wizardtower.<tailnet>.ts.net:7297 to it.
# The module's default port is kept because Serve's 443 on this host already
# proxies a dev server; give clients the :7297 address explicitly so they
# don't land on that first.
{
  imports = [ inputs.rex.nixosModules.default ];

  services.rex.loginServer = {
    enable = true;
    tailscaleServe.enable = true;
    # Only my own tailnet login, not `tailscale:*`: other people's devices share
    # this tailnet, and a Rex connection can run anything as the account.
    accounts.${username}.principals = [ "tailscale:aroman@github" ];
  };
}
