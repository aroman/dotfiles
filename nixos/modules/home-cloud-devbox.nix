{ config, cloudDevboxGit, ... }:

{
  # A cloud devbox is attached to remotely and never drives a local TUI, so run
  # herdr independently of a graphical session. The primary user lingers via
  # common.nix, so the unit starts at boot and survives SSH disconnects.
  imports = [ ./herdr-server.nix ];

  # These values are deliberately required by mkCloudDevbox. The shared
  # gitconfig is personal to this repository, so every cloud host must state
  # whose commits it will create rather than silently inheriting Avi's identity.
  home.file.".ssh/config.local".text = ''
    Host github.com
      IdentityFile ${cloudDevboxGit.githubIdentityFile}
  '';
  home.file.".gitconfig.local".text = ''
    [user]
      name = ${cloudDevboxGit.gitUserName}
      email = ${cloudDevboxGit.gitUserEmail}
      signingkey = ${cloudDevboxGit.gitSigningKey}
  '';
}
