{ config, pkgs, lib, ... }:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.systemd-boot.consoleMode = "5";
  boot.initrd.systemd.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;

  # Networking
  networking.networkmanager.enable = true;

  # iPhone USB tethering — runs usbmuxd + libimobiledevice and installs udev
  # rules so the ipheth kernel driver exposes the phone as a USB Ethernet
  # interface that NetworkManager can DHCP on. More stable than Wi-Fi hotspot
  # (no radio jitter) and charges the phone at the same time.
  services.usbmuxd.enable = true;

  # Use systemd-resolved so per-interface DNS works properly (Tailscale
  # MagicDNS on tailscale0, DHCP-provided DNS on wlan0/eth0). The fallback
  # servers kick in when all per-interface servers are unreachable — e.g.
  # hotel WiFi that blocks Tailscale's WireGuard UDP before the tunnel is up.
  services.resolved = {
    enable = true;
    settings.Resolve.FallbackDNS = [ "1.1.1.1" "8.8.8.8" ];
  };

  # Locale
  time.timeZone = null;  # managed at runtime via `timedatectl` / `tz` script
  i18n.defaultLocale = "en_US.UTF-8";

  # Niri compositor (provided by niri-flake)
  programs.niri.enable = true;
  programs.niri.package = pkgs.niri-unstable;

  # niri.service ExecStop drop-in is installed via home-manager (see
  # modules/home.nix).  We can't use NixOS's systemd.user.services.niri
  # here because it injects a narrow Environment=PATH= that masks the user
  # manager's PATH and breaks spawn-at-startup; and environment.etc can't
  # write under /etc/systemd/user/ without colliding with NixOS unit mgmt.

  # Display manager — greetd with tuigreet (lightweight, TTY-based)
  services.greetd = {
    enable = true;
    settings = {
      terminal.vt = lib.mkForce 2;
      default_session = {
        command = "${pkgs.tuigreet}/bin/tuigreet --time --remember --remember-session --asterisks --greeting 'hack the planet' --theme 'border=magenta;text=cyan;prompt=green;time=red;action=bold;button=yellow' --cmd niri-session";
        user = "greeter";
      };
    };
  };

  # Audio — PipeWire
  services.pipewire = {
    enable = true;
    alsa.enable = true;
    pulse.enable = true;
    # High-quality resampling and multi-rate support. Default resample.quality
    # is 4 (mediocre); 10 is near-transparent and cheap on modern CPUs.
    # Allowing 44100/96000 avoids resampling for CD and hi-res content when
    # the hardware supports it (e.g. CalDigit TS4 → Presonus E4).
    extraConfig.pipewire."10-audio-quality" = {
      "context.properties" = {
        "resample.quality" = 10;
        "default.clock.allowed-rates" = [ 44100 48000 96000 ];
      };
    };
    # Block Chromium-based apps (Vesktop, Chrome, Electron) from adjusting
    # mic volume at the OS level. WebRTC's automatic gain control changes the
    # PipeWire source volume directly, overriding user settings.
    # Ref: https://github.com/Vencord/Vesktop/issues/161
    # Ref: https://bbs.archlinux.org/viewtopic.php?id=301041
    extraConfig.pipewire-pulse."91-block-chromium-mic-adjust" = {
      "pulse.rules" = [{
        matches = [{ "application.name" = "~Chromium.*"; }];
        actions.quirks = [ "block-source-volume" ];
      }];
    };
    wireplumber = {
      enable = true;
      extraConfig = {
        "51-bluez-config" = {
          "monitor.bluez.properties" = {
            # Without explicit roles, some devices (e.g. Jabra Speak2 75) only get
            # HSP/HFP headset profiles and never negotiate A2DP high-quality audio.
            #
            # a2dp_source — send high-quality audio TO BT headphones/speakers
            # hfp_ag/hf   — two-way call audio (lower quality, with mic)
            #               WirePlumber auto-switches between A2DP and HFP when apps request a mic.
            "bluez5.roles" = [ "a2dp_source" "hfp_ag" "hfp_hf" ];
            "bluez5.enable-sbc-xq" = true;   # better quality SBC codec variant
            "bluez5.enable-msbc" = true;      # wideband voice for HFP calls
            "bluez5.enable-hw-volume" = true;  # sync volume to device hardware

            # 2026-04-25: LDAC currently broken in this nixpkgs pin (PipeWire
            # 1.6.2 + buggy libldac-dec from O2C14, which is a Ghidra-decompiled
            # decoder). Fails with LDACBT_ERR_FATAL during init and silently
            # kills A2DP entirely instead of falling back. Workaround lives in
            #   ~/.config/wireplumber/wireplumber.conf.d/51-disable-ldac.conf
            # (whitelists sbc/sbc_xq/aac/msbc/cvsd to exclude ldac).
            #
            # Proper fix is in nixos-unstable HEAD (PRs #502690 + #506221:
            # switch source to AOSP via open-vela/external_libldac, make decoder
            # support opt-out). Pick it up on next `nix flake update nixpkgs`,
            # then delete the drop-in. Or move the whitelist into this block
            # if you want to stay on the current pin.
          };
        };
      };
    };
  };

  # Real-time scheduling for PipeWire (prevents audio pops/crackles).
  # rtkit is a fallback; the primary method is PAM rlimits for the @audio
  # group, which lets PipeWire use SCHED_FIFO directly without rtkit.
  # Without these limits PipeWire stays on SCHED_OTHER and crackles under load.
  # Ref: https://docs.pipewire.org/page_module_rt.html
  security.rtkit.enable = true;
  security.pam.loginLimits = [
    { domain = "@audio"; type = "-"; item = "rtprio";  value = "95"; }
    { domain = "@audio"; type = "-"; item = "memlock"; value = "unlimited"; }
    { domain = "@audio"; type = "-"; item = "nice";    value = "-19"; }
  ];

  # Zeroconf/mDNS — needed for Spotify Connect device discovery
  services.avahi = {
    enable = true;
    nssmdns4 = true;
    openFirewall = true;
    publish = {
      enable = true;
      addresses = true;
    };
  };
  networking.firewall.allowedTCPPorts = [
    22     # SSH
    57621  # Spotify Connect
  ];
  networking.firewall.allowedUDPPorts = [
    7460   # belphegor (QUIC clipboard sharing)
  ];

  # SSH + Mosh
  services.openssh.enable = true;
  services.openssh.settings.AcceptEnv = [ "GHOSTTY_RESOURCES_DIR" "COLORTERM" ];
  # Auto-remove forwarded UNIX sockets (e.g. ~/.opener.sock from RemoteForward)
  # when the SSH session ends — without this, the socket file lingers and the
  # next reconnect fails with "remote port forwarding failed for listen path".
  services.openssh.settings.StreamLocalBindUnlink = "yes";
  programs.mosh.enable = true;

  # Tailscale
  services.tailscale.enable = true;
  services.tailscale.extraSetFlags = [ "--ssh" ];

  # Flatpak (TexturePacker, etc.)
  services.flatpak.enable = true;

  # Keyboard
  services.xserver.xkb = {
    layout = "us";
    options = "caps:escape";
  };
  # Also set console keymap for TTY
  console.useXkbConfig = true;

  # kmscon: userspace KMS console with real font rendering, truecolor, and
  # scrollback — replaces the in-kernel VT102 emulator on tty1/tty3-6.
  # tty2 is reserved for niri (see `terminal.vt = 2` above).
  services.kmscon = {
    enable = true;
    useXkbConfig = true;
    hwRender = false;  # pixman software rendering; GL backend has been flakier
    fonts = [{
      name = "CaskaydiaCove Nerd Font";
      package = pkgs.nerd-fonts.caskaydia-cove;
    }];
    extraConfig = ''
      font-size=24
      sb-size=10000
      # kmscon uses evdev directly (no libinput), so touchpad gestures
      # don't work — instead, raw BTN_* events from tap-to-click cause
      # accidental PRIMARY-selection pastes. Disable mouse entirely; use
      # Shift+PgUp/PgDn for scrollback.
      no-mouse
      xkb-repeat-delay=250
      xkb-repeat-rate=40
    '';
  };
  systemd.services."kmsconvt@tty2".enable = false;

  xdg.portal = {
    enable = true;
    extraPortals = [ pkgs.xdg-desktop-portal-gnome ];
  };

  # Fonts
  fonts = {
    packages = with pkgs; [
      cascadia-code
      nerd-fonts.caskaydia-cove
      inter
      geist-font
      # Non-Latin script coverage (CJK, Cyrillic, Arabic, etc.)
      noto-fonts
      noto-fonts-cjk-sans
    ];
    fontconfig.defaultFonts = {
      monospace = [ "CaskaydiaCove Nerd Font" ];
      sansSerif = [ "Inter" ];
      emoji = [ "Noto Color Emoji" ];
    };
  };

  # User account
  users.users.aroman = {
    isNormalUser = true;
    description = "aroman";
    extraGroups = [ "wheel" "networkmanager" "video" "input" "i2c" "audio" "kvm" ];
    shell = pkgs.fish;
  };

  # Enable fish system-wide (needed for it to be a valid login shell)
  programs.fish.enable = true;

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    settings.global.hide_env_diff = true;
  };

  programs.dconf.enable = true;

  # Polkit (needed by 1Password, niri, etc.)
  security.polkit.enable = true;
  # Disable niri-flake's bundled KDE polkit agent (badged replaces it)
  systemd.user.services.niri-flake-polkit.enable = false;

  # GNOME Keyring (for secrets, SSH agent, etc.)
  services.gnome.gnome-keyring.enable = true;

  # Removable media (udisks2 + gvfs so Nautilus can detect/mount USB drives)
  services.udisks2.enable = true;
  services.gvfs.enable = true;

  # Bluetooth
  hardware.bluetooth.enable = true;

  # I2C access for DDC/CI external monitor brightness control (via ddcutil)
  hardware.i2c.enable = true;

  # OOM protection — kill the biggest offender before the system freezes.
  # With zram (50%, swappiness=180), the kernel OOM killer doesn't fire until
  # ~35 GB virtual, by which point the CPU is saturated on zram compression
  # and the system is unresponsive. earlyoom intervenes much earlier.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;   # SIGTERM when <5% RAM free (~1.4 GB)
    freeSwapThreshold = 10; # ... and <10% swap free (~1.4 GB)
    freeMemKillThreshold = 2;   # SIGKILL when <2% RAM free (~560 MB)
    freeSwapKillThreshold = 5;  # ... and <5% swap free (~700 MB)
  };

  # Let downloaded binaries find the dynamic linker (Prisma, Playwright, etc.)
  programs.nix-ld.enable = true;
  programs.localsend.enable = true;

  # Allow unfree packages (Spotify, 1Password, Chrome, etc.)
  nixpkgs.config.allowUnfree = true;

  # Electron/Chromium apps: use native Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";
  environment.sessionVariables.QT_STYLE_OVERRIDE = "adwaita-dark";

  # Core system packages (user packages go in home.nix)
  environment.systemPackages = with pkgs; [
    android-tools  # adb + fastboot (udev rules handled by systemd 258)
    chafa
    curl
    file
    git
    lazygit
    lsof
    xwayland-satellite  # X11 support for niri — auto-spawned on demand
  ];

  nix.settings = {
    experimental-features = [ "nix-command" "flakes" ];
    substituters = [
      "https://niri.cachix.org"
      "https://vicinae.cachix.org"
    ];
    trusted-public-keys = [
      "niri.cachix.org-1:Wv0OmO7PsuocRKzfDoJ3mulSl7Z6oezYhGhR+3W2964="
      "vicinae.cachix.org-1:1kDrfienkGHPYbkpNj1mWTr7Fm1+zcenzgTizIcI3oc="
    ];
  };

  # Automatic garbage collection
  nix.gc = {
    automatic = true;
    dates = "weekly";
    options = "--delete-older-than 14d";
  };

  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.11";
}
