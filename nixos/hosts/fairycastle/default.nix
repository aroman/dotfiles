{ username, ... }:

let
  authorizedKeys = import ../../operator-authorized-keys.nix;
in
{
  networking.hostName = "fairycastle";

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.${username}.openssh.authorizedKeys.keys = authorizedKeys;
}
