{ config, cloudDevboxGit, ... }:

{
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

  # A cloud devbox is attached to remotely and never drives a local TUI, so
  # run herdr independently of a graphical session. The primary user lingers
  # via common.nix, so this starts at boot and survives SSH disconnects.
  systemd.user.services.herdr = {
    Unit = {
      Description = "herdr headless server";
      After = [ "network-online.target" ];
      Wants = [ "network-online.target" ];
    };
    Service = {
      Type = "simple";
      Environment = [
        "HERDR_CONFIG_PATH=${config.home.homeDirectory}/Projects/dotfiles/config/herdr/config.toml"
      ];
      ExecStart = "${config.home.homeDirectory}/.nix-profile/bin/herdr server";
      ExecStop = "${config.home.homeDirectory}/.nix-profile/bin/herdr server stop";
      Restart = "on-failure";
      RestartSec = 2;
    };
    Install.WantedBy = [ "default.target" ];
  };
}
