{ lib, pkgs, modulesPath, ... }:

let
  authorizedKeys = [
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICTTEi83oJZ4eRZwNOcyd/upzaR2gzcuM2tXTgNGVLwq wizardtower"
    "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIKxAflOijL7OuJtnCsbAyPNdS/Lo39Df6feWPhdk/oPW avi@magiccircle.studio"
  ];
in
{
  imports = [
    (modulesPath + "/virtualisation/google-compute-config.nix")
    ./disko.nix
  ];

  networking.hostName = "fairycastle";

  # The stock GCE module targets the legacy BIOS image layout. This instance
  # is UEFI and disko creates an ESP for systemd-boot.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.growPartition = lib.mkForce false;

  # disko normally emits a by-partlabel mount while the GCE module emits this
  # by-filesystem-label mount. The ext4 formatter in disko.nix creates `nixos`.
  fileSystems."/".device = lib.mkForce "/dev/disk/by-label/nixos";

  # The disk is provisioned to its final size by disko. Run discard in batches
  # instead of adding synchronous discard latency to the Hyperdisk I/O path.
  services.fstrim.enable = true;

  # Keep the latest stable kernel, matching wizardtower.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # The instance has no service account/scopes and uses the declarative users
  # below. OS Login would create a differently named account that cannot share
  # the home-manager configuration for `aroman`.
  security.googleOsLogin.enable = lib.mkForce false;

  # google-compute-config defaults the host firewall off in favor of GCP VPC
  # rules. Keep defense in depth and expose only the explicitly declared ports.
  networking.firewall.enable = lib.mkForce true;
  networking.firewall.interfaces.tailscale0.allowedTCPPortRanges = [
    { from = 4000; to = 5000; }
  ];

  # This host is an ordinary tailnet client; wizardtower remains the exit node.
  # Allow Tailscale's authenticated WireGuard transport through the host
  # firewall so peers can establish a direct path instead of using DERP.
  services.tailscale = {
    useRoutingFeatures = "client";
    openFirewall = true;
  };

  # SSH only: no password/PAM fallback and no public Mosh UDP range.
  programs.mosh.enable = lib.mkForce false;
  services.openssh.settings = {
    PasswordAuthentication = false;
    KbdInteractiveAuthentication = false;
    PermitRootLogin = "prohibit-password";
    AllowUsers = [ "root" "aroman" ];
  };

  users.users.root.openssh.authorizedKeys.keys = authorizedKeys;
  users.users.aroman.openssh.authorizedKeys.keys = authorizedKeys;

  # `aroman` intentionally has no password on this remote-only host.
  security.sudo.wheelNeedsPassword = false;

  # A persistent daily timer can catch up immediately after first boot. Skip
  # cleanly until the shared password and fairycastle-specific endpoints have
  # been provisioned; the next scheduled run starts automatically afterward.
  systemd.services.restic-backups-b2.unitConfig.ConditionPathExists = [
    "/etc/restic/password"
    "/etc/restic/b2-env"
    "/etc/restic/healthchecks-url"
  ];

  # 24 hardware threads: four builds with six cores each, matching the shape
  # and background scheduling policy used on wizardtower.
  nix.settings = {
    max-jobs = 4;
    cores = 6;
  };
}
