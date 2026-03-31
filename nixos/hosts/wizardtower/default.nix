{ config, pkgs, lib, ... }:

let
  sunshine-cuda = pkgs.sunshine.override { cudaSupport = true; };
in
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
  services.greetd.settings.default_session = lib.mkForce {
    command = "niri-session";
    user = "aroman";
  };

  # ── Sunshine (remote desktop streaming) ──────────────────────────
  # Streams the desktop to Moonlight clients. NvENC for hardware-accelerated
  # encoding on the RTX 2060 Super, KMS capture reads the framebuffer
  # directly (works with any Wayland compositor including niri).
  services.sunshine = {
    enable = true;
    package = sunshine-cuda;
    autoStart = true;
    capSysAdmin = true; # required for KMS capture on Wayland
    openFirewall = false; # Tailscale's ts-input chain already allows traffic between peers
    settings = {
      encoder = "nvenc";
      capture = "kms";
      origin_web_ui_allowed = "wan"; # allow access from Tailscale IPs
    };
    applications = {
      apps = [{
        name = "Desktop";
        image-path = "desktop.png";
      }];
    };
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
