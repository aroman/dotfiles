{ config, pkgs, lib, ... }:

{
  imports = [
    ../../badged.nix
  ];

  networking.hostName = "wizardtower";

  # Use latest stable kernel
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # NVIDIA RTX 2060 Super (proprietary driver)
  hardware.graphics.enable = true;
  hardware.nvidia = {
    modesetting.enable = true;
    open = false; # RTX 2060 Super needs the proprietary driver
    nvidiaSettings = true;
    package = config.boot.kernelPackages.nvidiaPackages.stable;
  };
  services.xserver.videoDrivers = [ "nvidia" ];

  # Auto-login — desktop tower is always on, skip the greeter so
  # niri and user services (Sunshine, etc.) start on boot.
  services.greetd.settings.initial_session = {
    command = "niri-session";
    user = "aroman";
  };

  # ── Sunshine (remote desktop streaming) ──────────────────────────
  # Streams the desktop to Moonlight clients via NvENC hardware encoding.
  # Uses KMS capture (reads framebuffer directly), works with any Wayland
  # compositor including niri.
  services.sunshine = {
    enable = true;
    autoStart = true;
    capSysAdmin = true; # required for KMS capture on Wayland
    openFirewall = true;
  };

  # Sunshine needs uinput access for remote keyboard/mouse input
  services.udev.extraRules = ''
    KERNEL=="uinput", MODE="0660", GROUP="input", SYMLINK+="uinput"
  '';
  users.users.aroman.extraGroups = [ "input" ];

  # 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "aroman" ];
  };
}
