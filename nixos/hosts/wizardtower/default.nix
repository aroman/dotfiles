{ config, pkgs, lib, ... }:

let
  sunshine-cuda = pkgs.sunshine.override { cudaSupport = true; };
in
{
  imports = [
    ../../badged.nix
  ];

  networking.hostName = "wizardtower";

  # Magic Circle dev servers — exposed to Tailscale peers only (loopback is already exempt).
  networking.firewall.interfaces.tailscale0.allowedTCPPortRanges = [
    { from = 4000; to = 5000; }
  ];

  # Sunshine — tailnet-only. NixOS's tailscale module only adds tailscale0
  # to trustedInterfaces when useRoutingFeatures is "server"/"both"; on the
  # default "client" the host firewall fully applies to tailnet traffic, so
  # per-interface allow rules are required.
  networking.firewall.interfaces.tailscale0.allowedTCPPorts = [
    47984 47989 47990 48010
  ];
  networking.firewall.interfaces.tailscale0.allowedUDPPorts = [
    47998 47999 48000 48010
  ];

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
    openFirewall = false; # tailnet-only; see firewall.interfaces.tailscale0 above
    settings = {
      encoder = "nvenc";
      capture = "kms";
      # No output_name: Sunshine auto-picks the active DRM connector. Works because
      # prep-cmd disables DP-1 (LG) before streaming, leaving HDMI-A-1 as the only
      # active output. (Sunshine misparses string output_names like "HDMI-A-1" as
      # integers on this version; numeric indices work but are fragile.)
      origin_web_ui_allowed = "wan"; # allow access from Tailscale IPs
    };
    applications = {
      apps = [{
        name = "Desktop";
        image-path = "desktop.png";
        prep-cmd = [{
          do = "/home/aroman/.local/bin/toggle-streaming-res remote";
          undo = "/home/aroman/.local/bin/toggle-streaming-res local";
        }];
      }];
    };
  };

  # Sunshine needs uinput access for remote keyboard/mouse input.
  # nixpkgs' sunshine module installs its own udev rule setting
  # /dev/uinput to group=uinput (more specific SUBSYSTEM rule wins over a
  # bare KERNEL match), so the user must be in `uinput`, not `input`.
  users.users.aroman.extraGroups = [ "input" "uinput" ];

  # 1Password
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "aroman" ];
  };

  # Headless: no graphical login means PAM never grabs a login password to
  # unlock the keyring, so gnome-keyring-daemon can't actually serve
  # secrets/keys here. Worse, its PAM module exports SSH_AUTH_SOCK to its
  # own (locked, useless) socket at session start, shadowing the OpenSSH
  # ssh-agent we run via programs.ssh.startAgent. No NixOS option exists
  # to disable just the SSH bit (nixpkgs#166887), so we turn the whole
  # keyring off on this host.
  services.gnome.gnome-keyring.enable = lib.mkForce false;
}
