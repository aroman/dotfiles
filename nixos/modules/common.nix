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
    # avahi owns mDNS; don't double-bind UDP 5353.
    settings.Resolve.MulticastDNS = "no";
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

  # Display manager — greetd, with tuigreet wrapped in foot under cage.
  # cage owns the DRM master and handles monitor hotplug as Wayland output
  # events, so plugging/unplugging displays no longer reflows the kernel
  # framebuffer console mid-render (the cause of the duplicated-line
  # artifacts on raw VT2). After auth, greetd kills the cage/foot/tuigreet
  # tree and execs niri-session on the same VT.
  services.greetd =
    let
      # cage doesn't advertise a scale, so disable foot's dpi-aware path
      # and pick a font size large enough for the 2560x1600 panel.
      # Palette is max-neon CGA — tuigreet's --theme uses ANSI color
      # names, so the rendered look is entirely down to the palette.
      footConfig = pkgs.writeText "foot-greeter.ini" ''
        font=CaskaydiaCove Nerd Font:size=24
        dpi-aware=no
        pad=24x24

        [colors-dark]
        foreground=cccccc
        background=000000
        regular0=000000
        regular1=ff003c
        regular2=00ff66
        regular3=ffd000
        regular4=00aaff
        regular5=ff00ff
        regular6=00ffff
        regular7=cccccc
        bright0=555555
        bright1=ff5577
        bright2=55ff88
        bright3=ffdf55
        bright4=55bbff
        bright5=ff55ff
        bright6=55ffff
        bright7=ffffff
      '';
      tuigreetArgs = lib.escapeShellArgs [
        "--time" "--remember" "--remember-session" "--asterisks"
        "--issue"
        "--greeting" "hack the planet"
        "--theme" "border=magenta;text=cyan;prompt=green;time=red;action=bold;button=yellow"
        "--cmd" "niri-session"
      ];
    in
    {
      enable = true;
      settings = {
        terminal.vt = lib.mkForce 2;
        default_session = {
          # -m last: only render on the last-connected output. cage's
          # `extend` default spans the greeter across both displays
          # when docked; cage 0.3 has no per-output picker.
          command = "${pkgs.cage}/bin/cage -s -m last -- "
            + "${pkgs.foot}/bin/foot --config=${footConfig} -- "
            + "${pkgs.tuigreet}/bin/tuigreet ${tuigreetArgs}";
          user = "greeter";
        };
      };
    };
  # tuigreet's --issue reads /etc/issue and renders it above the prompt.
  # Braille-art Jolly Roger.
  environment.etc."issue".text = ''
    ⠀⠀⠀⠀⠀⢀⣤⣶⣾⣿⣿⣿⣷⣶⣤⡀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⢰⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡆⠀⠀⠀⠀
    ⠀⠀⠀⠀⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⠀⠀⠀⠀
    ⠀⠀⠀⠀⢸⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⣿⡏⠀⠀⠀⠀
    ⠀⠀⠀⠀⢰⡟⠛⠉⠙⢻⣿⡟⠋⠉⠙⢻⡇⠀⠀⠀⠀
    ⠀⠀⠀⠀⢸⣷⣀⣀⣠⣾⠛⣷⣄⣀⣀⣼⡏⠀⠀⠀⠀
    ⠀⠀⣀⠀⠀⠛⠋⢻⣿⣧⣤⣸⣿⡟⠙⠛⠀⠀⣀⠀⠀
    ⢀⣰⣿⣦⠀⠀⠀⠼⣿⣿⣿⣿⣿⡷⠀⠀⠀⣰⣿⣆⡀
    ⢻⣿⣿⣿⣧⣄⠀⠀⠁⠉⠉⠋⠈⠀⠀⣀⣴⣿⣿⣿⡿
    ⠀⠀⠀⠈⠙⠻⣿⣶⣄⡀⠀⢀⣠⣴⣿⠿⠛⠉⠁⠀⠀
    ⠀⠀⠀⠀⠀⠀⠀⠉⣻⣿⣷⣿⣟⠉⠀⠀⠀⠀⠀⠀⠀
    ⠀⠀⠀⠀⢀⣠⣴⣿⠿⠋⠉⠙⠿⣷⣦⣄⡀⠀⠀⠀⠀
    ⣴⣶⣶⣾⡿⠟⠋⠀⠀⠀⠀⠀⠀⠀⠙⠻⣿⣷⣶⣶⣦
    ⠙⢻⣿⡟⠁⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⢿⣿⡿⠋
    ⠀⠀⠉⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠀⠉⠀⠀
  '';

  # Suppress the cursor in the greeter — cage has no --no-cursor flag, so
  # we point it at a custom xcursor theme whose every entry is a 1x1
  # transparent pixel. cage loads it happily and draws nothing visible.
  # Scoped to greetd's unit so the rest of the system is unaffected.
  systemd.services.greetd.environment =
    let
      # Inline base64 of a 67-byte 1x1 transparent PNG — avoids pulling
      # imagemagick (~150MB build dep) just to emit one tiny file.
      invisibleCursors = pkgs.runCommandLocal "invisible-cursor" {
        nativeBuildInputs = [ pkgs.xorg.xcursorgen ];
      } ''
        themeDir=$out/share/icons/invisible
        mkdir -p $themeDir/cursors
        printf '[Icon Theme]\nName=Invisible\n' > $themeDir/index.theme
        printf '%s' 'iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mNkAAIAAAoAAv/lxKUAAAAASUVORK5CYII=' \
          | base64 -d > $TMPDIR/blank.png
        echo "1 0 0 $TMPDIR/blank.png" > $TMPDIR/cfg
        xcursorgen $TMPDIR/cfg $themeDir/cursors/default
        for name in left_ptr arrow text xterm pointer pointing_hand \
                    hand1 hand2 grabbing crosshair fleur watch wait progress \
                    top_left_corner top_right_corner bottom_left_corner \
                    bottom_right_corner left_side right_side top_side \
                    bottom_side sb_v_double_arrow sb_h_double_arrow help \
                    question_arrow x_cursor; do
          ln -s default $themeDir/cursors/$name
        done
      '';
    in
    {
      XCURSOR_THEME = "invisible";
      XCURSOR_PATH = "${invisibleCursors}/share/icons";
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

  # Zeroconf/mDNS — Sunshine publishes via libavahi-client; nssmdns4
  # resolves *.local hostnames.
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
    22  # SSH
  ];

  # SSH + Mosh
  services.openssh.enable = true;
  services.openssh.settings.AcceptEnv = [ "GHOSTTY_RESOURCES_DIR" "COLORTERM" ];
  # Auto-remove forwarded UNIX sockets (e.g. ~/.opener.sock from RemoteForward)
  # when the SSH session ends — without this, the socket file lingers and the
  # next reconnect fails with "remote port forwarding failed for listen path".
  services.openssh.settings.StreamLocalBindUnlink = "yes";
  programs.mosh.enable = true;

  # Local ssh-agent so passphrased keys can be unlocked once and stay loaded
  # across SSH sessions (vs. relying on agent forwarding, whose per-connection
  # SSH_AUTH_SOCK goes stale inside long-lived tmux panes).
  # Pair with `loginctl enable-linger <user>` so the agent survives between
  # disconnects — then `ssh-add` is a once-per-boot operation.
  programs.ssh.startAgent = true;

  # Tailscale
  services.tailscale.enable = true;
  # tailscaled's Close() deadlocks in magicsock during shutdown, hanging
  # reboots ~45s until its own watchdog self-kills. SIGKILL sooner.
  # https://github.com/tailscale/tailscale/issues/3932
  systemd.services.tailscaled.serviceConfig.TimeoutStopSec = "3s";
  # Don't churn tailscaled on switch-to-configuration. controlplane.tailscale.com
  # is anycast from a single EU POP (tailscale/tailscale#16653); fresh-register
  # flows are fragile across transatlantic Tier-1 transit, and exponential
  # backoff turns brief upstream issues into 20+ min outages. Pick up changes
  # on reboot instead.
  systemd.services.tailscaled.restartIfChanged = false;

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
    # Keep the user systemd instance alive between logins so ssh-agent
    # (programs.ssh.startAgent) survives across SSH disconnects — making
    # `ssh-add` a once-per-boot operation rather than once-per-login.
    linger = true;
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

  # GNOME Keyring (for libsecret consumers — NetworkManager Wi-Fi, Chromium
  # logins, etc.). Daemon is D-Bus activated on first use.
  services.gnome.gnome-keyring.enable = true;
  # Recent nixpkgs auto-enables gcr-ssh-agent whenever gnome-keyring is on,
  # which conflicts with programs.ssh.startAgent above. We use the OpenSSH
  # agent, so opt out of the GCR one.
  services.gnome.gcr-ssh-agent.enable = false;
  # Also stop pam_gnome_keyring from auto-starting gnome-keyring-daemon at
  # greetd login. That `session optional ... auto_start` line exports
  # SSH_AUTH_SOCK=/run/user/UID/gcr/ssh into the PAM env, which propagates
  # into the systemd user manager and shadows the OpenSSH agent socket.
  # Since gnome-keyring 46+ moved SSH out into gcr-ssh-agent (disabled
  # above), the socket has no listener — `ssh-add` gets "Connection
  # refused". Fingerprint auth never feeds PAM a password, so the daemon
  # would start locked anyway and not actually auto-unlock the keyring;
  # nothing of value lost.
  security.pam.services.greetd.enableGnomeKeyring = lib.mkForce false;

  # Removable media (udisks2 + gvfs so Nautilus can detect/mount USB drives)
  services.udisks2.enable = true;
  services.gvfs.enable = true;
  # Drop the wsdd backend (Windows network discovery). gvfs ships wsdd.mount
  # but not the `wsdd` helper, so Nautilus' network browser spams
  # "Failed to spawn the wsdd daemon" every time it enumerates mounts.
  services.gvfs.package = pkgs.gnome.gvfs.overrideAttrs (prev: {
    postInstall = (prev.postInstall or "") + ''
      rm -f $out/share/gvfs/mounts/wsdd.mount $out/libexec/gvfsd-wsdd
    '';
  });
  # gvfs ships five volume monitors and starts them all at login. Mask the
  # two that are pure dead weight here: no digital camera, no GNOME Online
  # Accounts (Google Drive in Nautilus). D-Bus activation uses
  # `SystemdService=`, so masking the unit also blocks dbus-activation.
  # Keep udisks2 (USB), afc (iPhone via usbmuxd), mtp (Android).
  systemd.user.services.gvfs-gphoto2-volume-monitor.enable = false;
  systemd.user.services.gvfs-goa-volume-monitor.enable = false;

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

  # Qt theming — installs adwaita-qt for both Qt5 and Qt6 and sets
  # QT_STYLE_OVERRIDE / QT_QPA_PLATFORMTHEME. Required so Tiled's
  # "Native" application-style preference resolves to adwaita-dark
  # (without this, Qt5 falls back to light Fusion).
  qt = {
    enable = true;
    platformTheme = "gnome";
    style = "adwaita-dark";
  };

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

  programs.nh = {
    enable = true;
    flake = "/home/aroman/Projects/dotfiles/nixos";
  };

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
