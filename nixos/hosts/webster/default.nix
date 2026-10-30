{ username, ... }:

let
  # Add the developer's workstation keys here during onboarding.
  developerAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM68lVbsqE8bbKXUyvDQdSovm0xds/lmgxxBqU/vIWpf xiaoxiao@magiccircle.studio"
  ];
  # The developer's Tailscale login, as "tailscale:<login>". webster is shared
  # to their own tailnet, so this is the login of the account it's shared with.
  developerTailscaleLogins = [ "tailscale:xx.michael.long@gmail.com" ];
  operatorAuthorizedKeys = import ../../operator-authorized-keys.nix;
in
{
  imports = [ ../../modules/rex.nix ];

  networking.hostName = "webster";

  # Cloud devbox — no display of any kind, reached only over SSH. Switches
  # off the idle/lock stack, which would otherwise be built for a session
  # that never exists (see modules/options.nix).
  local.headlessDisplay = true;

  users.users.root.openssh.authorizedKeys.keys = operatorAuthorizedKeys;
  users.users.${username}.openssh.authorizedKeys.keys =
    operatorAuthorizedKeys ++ developerAuthorizedKeys;

  services.rex.loginServer.accounts.${username}.principals =
    developerTailscaleLogins;
}
