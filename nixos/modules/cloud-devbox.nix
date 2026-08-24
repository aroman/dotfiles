{
  config,
  lib,
  pkgs,
  modulesPath,
  username,
  resticRepository,
  ...
}:

{
  imports = [
    (modulesPath + "/virtualisation/google-compute-config.nix")
  ];

  # The stock GCE module targets the legacy BIOS image layout. Cloud devboxes
  # boot with UEFI, and cloud-devbox-disko.nix creates an ESP for systemd-boot.
  boot.loader.grub.enable = lib.mkForce false;
  boot.loader.efi.canTouchEfiVariables = lib.mkForce false;
  boot.growPartition = lib.mkForce false;

  # disko creates the `nixos` label. The GCE module also defines this mount
  # using a filesystem label, so force both definitions to the same device.
  fileSystems."/".device = lib.mkForce "/dev/disk/by-label/nixos";

  # Hyperdisk is provisioned to its final size by disko. Run discard in
  # batches rather than adding synchronous discard latency to every write.
  services.fstrim.enable = true;

  boot.kernelPackages = pkgs.linuxPackages_latest;
  boot.initrd.availableKernelModules = [ "nvme" ];
  boot.initrd.kernelModules = [];
  boot.kernelModules = [];
  boot.extraModulePackages = [];
  hardware.cpu.intel.updateMicrocode =
    lib.mkDefault config.hardware.enableRedistributableFirmware;

  # A 75%-of-RAM logical zram device gives cold, compressible dev-server heaps
  # somewhere cheap to go without putting network I/O in the reclaim path.
  # There is intentionally no disk-backed swap on these hosts.
  zramSwap = {
    enable = true;
    memoryPercent = 75;
  };
  swapDevices = [];

  boot.kernel.sysctl = {
    "vm.swappiness" = 180;
    "vm.watermark_boost_factor" = 0;
    "vm.watermark_scale_factor" = 125;
    "vm.page-cluster" = 0;
  };

  # These hosts have no service account/scopes and use declarative users.
  # OS Login would create a differently named account that cannot share the
  # Home Manager configuration for `username`.
  security.googleOsLogin.enable = lib.mkForce false;

  # Do not let GCE metadata create mutable users or execute metadata scripts.
  # The guest agent remains available for the platform integration supplied by
  # google-compute-config.nix, but identity and boot-time code are declarative.
  users.mutableUsers = false;

  # Keep defense in depth even though GCE also has VPC firewall rules.
  networking.firewall.enable = lib.mkForce true;
  networking.firewall.interfaces.tailscale0.allowedTCPPortRanges = [
    { from = 4000; to = 5000; }
  ];

  # Ordinary tailnet clients; a separate stable host remains the exit node.
  # Opening the WireGuard transport permits direct paths instead of DERP.
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
    AllowUsers = [ "root" username ];
  };

  # The primary user intentionally has no password on remote-only hosts.
  security.sudo.wheelNeedsPassword = false;

  # A persistent daily timer can catch up immediately after first boot. When
  # backups are enabled, skip cleanly until the three untracked secrets exist.
  systemd.services =
    {
      google-startup-scripts.wantedBy = lib.mkForce [];
      google-shutdown-scripts.wantedBy = lib.mkForce [];
    }
    // lib.optionalAttrs (resticRepository != null) {
      restic-backups-b2.unitConfig.ConditionPathExists = [
        "/etc/restic/password"
        "/etc/restic/b2-env"
        "/etc/restic/healthchecks-url"
      ];
    };

  # 24+ hardware threads: four builds with six cores each leaves interactive
  # headroom and matches the background scheduling policy on wizardtower.
  nix.settings = {
    max-jobs = 4;
    cores = 6;
  };
}
