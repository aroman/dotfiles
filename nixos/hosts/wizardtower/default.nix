{ config, pkgs, lib, ... }:

{
  networking.hostName = "wizardtower";

  # GCE administration for cloud dev boxes such as fairycastle. Authentication
  # remains per-user state under ~/.config/gcloud.
  environment.systemPackages = [ pkgs.google-cloud-sdk ];

  # No real monitor — drives a Ugreen HDMI dummy plug for Sunshine streaming.
  # Disables idle-driven monitor power-off (see modules/options.nix).
  local.headlessDisplay = true;

  # Exit node — route other tailnet peers' internet egress through this host.
  # "server" flips on net.ipv4/ipv6 forwarding and adds tailscale0 to
  # networking.firewall.trustedInterfaces. (Use "both" if wizardtower should
  # also *use* other exit nodes / accept subnet routes itself.)
  #
  # extraSetFlags drives a tailscaled-set.service oneshot that re-runs
  # `tailscale set --advertise-exit-node` on every activation, so the
  # advertisement lives in the flake rather than only in tailscaled's local
  # state — idempotent, no re-auth. The exit node still has to be approved once
  # in the Tailscale admin console. To stop advertising later, change the flag
  # to "--advertise-exit-node=false" instead of just deleting the line (a flag
  # that's no longer passed isn't un-set in tailscaled's prefs).
  #
  # Note: because tailscale0 is now a trusted interface, the per-port allow
  # rules below are redundant — every listening port is already reachable from
  # tailnet peers. Kept so this host still curates tailnet exposure if exit-node
  # routing is ever turned back off.
  services.tailscale.useRoutingFeatures = "server";
  services.tailscale.extraSetFlags = [ "--advertise-exit-node" ];

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

  # ── SSH: keys only ───────────────────────────────────────────────
  # sshd here binds 0.0.0.0:22 and services.openssh.openFirewall defaults to
  # true, so port 22 is reachable on every interface — not just tailscale0.
  # Password logins over that are the exposure worth closing.
  #
  # BOTH settings are required. Disabling PasswordAuthentication alone is not
  # enough: UsePAM is yes and KbdInteractiveAuthentication was yes, and PAM
  # will happily perform ordinary password auth through the keyboard-interactive
  # path. Turning off only the first gives the appearance of key-only auth
  # while passwords still work.
  #
  # This affects SSH only — console/tty login and sudo still use the account
  # password, so physical access remains a way back in.
  services.openssh.settings.PasswordAuthentication = false;
  services.openssh.settings.KbdInteractiveAuthentication = false;

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

  # Power button — this headless always-on tower was accidentally powered off
  # by a short press of the chassis power button (2026-07-13), so ignore the
  # short press entirely. A deliberate ~1s hold still does a clean shutdown via
  # logind, and the firmware ~4s force-off remains as the hardware fallback.
  services.logind.settings.Login = {
    HandlePowerKey = "ignore";
    HandlePowerKeyLongPress = "poweroff";
  };

  # ── CPU (Ryzen 9 5900X, 12C/24T) ─────────────────────────────────
  # Nix build parallelism. modules/common.nix sets a conservative floor of
  # 2×4 = 8 threads; this box has 24, so that left two thirds of the CPU
  # idle during builds. 4×6 = 24 saturates it.
  #
  # Safe to saturate here precisely *because* common.nix already runs
  # nix-daemon and every build child at SCHED_IDLE with CPUWeight=20 —
  # builds are preempted by any interactive task regardless of how many
  # of them there are. The job cap was redundant with that, not additive
  # to it. Favour jobs over cores-per-job (4×6 rather than 6×4 would also
  # total 24) only loosely: many derivations don't scale past a few
  # threads, so the extra concurrency is where the throughput is.
  nix.settings = {
    max-jobs = 4;
    cores = 6;
  };

  # amd-pstate runs in active mode (amd-pstate-epp) with the powersave
  # governor. The governor is right — cores should still clock down when
  # idle — but the driver's default EPP bias of balance_performance is
  # tuned for battery life. This tower is always on AC, so bias the CPPC
  # hint fully toward performance. This changes ramp-up aggressiveness on
  # bursty loads, not sustained all-core throughput (which already hits
  # ~4.24 GHz all-core here).
  #
  # powerManagement.cpuFreqGovernor is not the knob for this — setting it to
  # "performance" would pin max frequency rather than just bias the hint.
  # boot.kernel.sysfs writes the attribute directly, backed by systemd path
  # units that fire as soon as each policy dir appears, so this also survives
  # CPU hotplug and resume without a separate hook.
  boot.kernel.sysfs.devices.system.cpu.cpufreq."policy[0-9]*"
    .energy_performance_preference = "performance";

  # ── Sunshine (remote desktop streaming) ──────────────────────────
  # Streams the desktop to Moonlight clients. NvENC for hardware-accelerated
  # encoding on the RTX 2060 Super, KMS capture reads the framebuffer
  # directly (works with any Wayland compositor including niri).
  services.sunshine = {
    enable = true;
    # cudaSupport pulls in the NvENC encode path; the CUDA EULA is accepted
    # via nixpkgs.config.allowUnfree in modules/common.nix.
    package = pkgs.sunshine.override { cudaSupport = true; };
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
      # 2026.516+ requires CSRF allow-list for non-localhost web UI origins.
      # Localhost variants are exempt by default; add tailnet origins here.
      csrf_allowed_origins = "https://100.116.179.31:47990,https://wizardtower.marlin-antares.ts.net:47990";
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
  # (`input` itself is already granted in modules/common.nix.)
  users.users.aroman.extraGroups = [ "uinput" ];

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
