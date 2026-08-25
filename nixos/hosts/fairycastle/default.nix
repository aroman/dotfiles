{ username, ... }:

let
  authorizedKeys = import ../../operator-authorized-keys.nix;
in
{
  networking.hostName = "fairycastle";

  # Cloud devbox — no display of any kind, reached only over SSH. Switches
  # off the idle/lock stack, which would otherwise be built for a session
  # that never exists (see modules/options.nix).
  local.headlessDisplay = true;

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.${username}.openssh.authorizedKeys.keys = authorizedKeys;
}
