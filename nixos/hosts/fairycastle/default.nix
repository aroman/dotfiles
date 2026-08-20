{ username, ... }:

let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTTEi83oJZ4eRZwNOcyd/upzaR2gzcuM2tXTgNGVLwq wizardtower"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKxAflOijL7OuJtnCsbAyPNdS/Lo39Df6feWPhdk/oPW avi@magiccircle.studio"
  ];
in
{
  networking.hostName = "fairycastle";

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.${username}.openssh.authorizedKeys.keys = authorizedKeys;
}
