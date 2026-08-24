{ username, ... }:

let
  # Add the developer's workstation keys here during onboarding.
  developerAuthorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIM68lVbsqE8bbKXUyvDQdSovm0xds/lmgxxBqU/vIWpf xiaoxiao@magiccircle.studio"
  ];
  operatorAuthorizedKeys = import ../../operator-authorized-keys.nix;
in
{
  networking.hostName = "webster";

  users.users.root.openssh.authorizedKeys.keys = operatorAuthorizedKeys;
  users.users.${username}.openssh.authorizedKeys.keys =
    operatorAuthorizedKeys ++ developerAuthorizedKeys;
}
