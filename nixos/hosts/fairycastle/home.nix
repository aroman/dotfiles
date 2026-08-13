{ config, ... }:

{
  imports = [
    ../../modules/home.nix
  ];

  # Per-machine GitHub identity. The private key remains local to fairycastle
  # and is unlocked into its persistent ssh-agent once per boot.
  home.file.".ssh/config.local".text = ''
    Host github.com
      IdentityFile ~/.ssh/fairycastle
  '';
  home.file.".gitconfig.local".text = ''
    [user]
      signingkey = ~/.ssh/fairycastle.pub
  '';

  # This host is attached to remotely and never drives a local TUI, so run the
  # herdr server independently of any graphical session. `aroman` has lingering
  # enabled in modules/common.nix, so the unit starts at boot and survives SSH
  # disconnects.
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
