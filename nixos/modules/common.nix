{ config, pkgs, lib, inputs, ... }:

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
  # Pure ASCII — multi-byte glyphs (Braille, emoji, box-drawing) panic
  # ratatui's width calc and crash the greeter.
  environment.etc."issue".text = "\n--=[ hack the planet ]=--\n\n";

  # Suppress the cursor in the greeter — cage has no --no-cursor flag, so
  # we point it at a custom xcursor theme whose every entry is a 1x1
  # transparent pixel. cage loads it happily and draws nothing visible.
  # Scoped to greetd's unit so the rest of the system is unaffected.
  systemd.services.greetd.environment =
    let
      # Inline base64 of a 67-byte 1x1 transparent PNG — avoids pulling
      # imagemagick (~150MB build dep) just to emit one tiny file.
      invisibleCursors = pkgs.runCommandLocal "invisible-cursor" {
        nativeBuildInputs = [ pkgs.xcursorgen ];
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

  # Apple TVs / HomePods act as Thread Border Routers and broadcast IPv6
  # Router Advertisements on Wi-Fi with short prefix lifetimes (~28min). Each
  # cycle the kernel adds/removes ULA addresses, which tailscale treats as a
  # "major link change" and rebinds every wireguard socket, stalling all
  # streams. See https://isc.sans.edu/diary/30336. No toggle on the Apple TV
  # to stop this; the categorical fix for a roaming laptop is to accept RAs
  # only from the current network's actual IPv6 default gateway.
  #
  # nft chain stays empty (fail-open: accept all RAs) until the NM dispatcher
  # populates it on connection-up with the discovered gateway's MAC. On
  # IPv4-only networks the chain stays empty and nothing is filtered. On
  # disconnect the dispatcher flushes the chain.
  networking.nftables.enable = true;
  networking.nftables.tables.ra-filter = {
    family = "ip6";
    content = ''
      chain input {
        type filter hook input priority -200; policy accept;
      }
    '';
  };
  networking.networkmanager.dispatcherScripts = [
    {
      type = "basic";
      source = pkgs.writeShellScript "ra-whitelist" ''
        set -u
        IFACE="''${1:-}"
        ACTION="''${2:-}"
        [ "$IFACE" = "lo" ] && exit 0

        NFT=${pkgs.nftables}/bin/nft
        IP=${pkgs.iproute2}/bin/ip

        flush_chain() {
          $NFT flush chain ip6 ra-filter input 2>/dev/null || true
        }

        case "$ACTION" in
          up|dhcp6-change)
            # Wait briefly for the IPv6 default route to land via SLAAC.
            gw=""
            for _ in 1 2 3 4 5 6 7 8 9 10; do
              gw=$($IP -6 route show default dev "$IFACE" 2>/dev/null \
                | awk '/^default via/ {print $3; exit}')
              [ -n "$gw" ] && break
              sleep 1
            done
            # IPv4-only network (no v6 gateway) — leave RAs unfiltered.
            [ -z "$gw" ] && { flush_chain; exit 0; }

            # Resolve gateway link-local → MAC via the neighbor table.
            mac=""
            for _ in 1 2 3 4 5; do
              mac=$($IP -6 neigh show "$gw" dev "$IFACE" 2>/dev/null \
                | awk '/lladdr/ {print $5; exit}')
              [ -n "$mac" ] && break
              sleep 1
            done
            [ -z "$mac" ] && { flush_chain; exit 0; }

            $NFT -e "flush chain ip6 ra-filter input
              add rule ip6 ra-filter input iifname \"$IFACE\" icmpv6 type 134 ether saddr $mac accept
              add rule ip6 ra-filter input iifname \"$IFACE\" icmpv6 type 134 drop"
            ;;
          down)
            flush_chain
            ;;
        esac
      '';
    }
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
    # hwaccel defaults off → pixman software rendering; GL backend has been flakier.
    config = {
      # Font lives in fonts.packages (nerd-fonts.caskaydia-cove); reference by name.
      font-name = "CaskaydiaCove Nerd Font";
      font-size = 24;
      sb-size = 10000;
      # kmscon uses evdev directly (no libinput), so touchpad gestures
      # don't work — instead, raw BTN_* events from tap-to-click cause
      # accidental PRIMARY-selection pastes. Disable mouse entirely; use
      # Shift+PgUp/PgDn for scrollback. (boolean false → renders as `no-mouse`)
      mouse = false;
      xkb-repeat-delay = 250;
      xkb-repeat-rate = 40;
      palette = "custom";
      palette-foreground = "218,218,218";
      palette-background = "10,13,16";
      palette-black = "35,42,45";
      palette-red = "229,116,116";
      palette-green = "140,207,126";
      palette-yellow = "229,199,107";
      palette-blue = "103,176,232";
      palette-magenta = "196,127,213";
      palette-cyan = "108,191,191";
      palette-light-grey = "179,185,184";
      palette-dark-grey = "70,78,80";
      palette-light-red = "239,126,126";
      palette-light-green = "150,217,136";
      palette-light-yellow = "244,214,122";
      palette-light-blue = "113,186,242";
      palette-light-magenta = "206,137,223";
      palette-light-cyan = "103,203,231";
      palette-white = "189,195,194";
    };
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

  # Vicinae 0.21+ expects its input-injection helper at
  # /run/wrappers/bin/vicinae-input-server with elevated access so it can
  # open /dev/uinput. Upstream's installer applies cap_dac_override=ep, but
  # that's a global DAC bypass — way broader than this needs. Since
  # /dev/uinput is group `uinput` (created by hardware.uinput, which
  # sunshine pulls in), setgid'ing the wrapper to that group gives the
  # helper exactly the access it needs and nothing else.
  security.wrappers.vicinae-input-server = {
    source = "${inputs.vicinae.packages.${pkgs.stdenv.hostPlatform.system}.default}/libexec/vicinae/vicinae-input-server";
    owner = "root";
    group = "uinput";
    setgid = true;
  };

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

  # PSI-driven userspace OOM: watch cgroup memory pressure (time-stalled, not
  # free%) and kill whole cgroups before the kernel OOM has to fire. Pairs
  # with earlyoom (PSI handles the "thrashing but RAM not yet empty" case;
  # earlyoom handles the "RAM gone, no PSI signal" case).
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    enableRootSlice = true;
    settings.OOM.DefaultMemoryPressureDurationSec = "20s";
  };

  # Let downloaded binaries find the dynamic linker (Prisma, Playwright, etc.)
  programs.nix-ld.enable = true;
  programs.localsend.enable = true;

  # Allow unfree packages (Spotify, 1Password, Chrome, etc.)
  nixpkgs.config.allowUnfree = true;

  # Electron/Chromium apps: use native Wayland
  environment.sessionVariables.NIXOS_OZONE_WL = "1";

  # nautilus-python's loader walks XDG_DATA_DIRS for .py extensions; the per-user
  # profile aggregator needs this subdir whitelisted or the extensions vanish from
  # /etc/profiles/per-user/<u>/share/nautilus-python/extensions/.
  environment.pathsToLink = [ "/share/nautilus-python/extensions" ];

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
    # Cap parallelism to leave interactive headroom. Default is
    # max-jobs=nproc × cores=nproc = 16×16 = 256 potential compiler procs.
    # 2×4 = 8 of 16 threads (~50%), 8 always free for niri/shell/browser.
    max-jobs = 2;
    cores = 4;
  };

  # Run nix-daemon (and all build children) at idle CPU + IO priority. Builds
  # only get scheduled when no SCHED_NORMAL task wants the CPU, so backgrounded
  # `nixos-rebuild` stays out of the way of interactive work entirely. Cost is
  # a small build-time increase only while you're actively using the machine.
  nix.daemonCPUSchedPolicy = "idle";
  nix.daemonIOSchedClass = "idle";
  nix.daemonIOSchedPriority = 7;

  # Cgroup isolation for nix builds. SCHED_IDLE handles the "build never
  # preempts interactive work" case absolutely; the slice gives proportional
  # throttling (CPUWeight=20 vs user.slice default 100 → user gets ~5× share
  # under contention) and — most importantly — a memory ceiling so builds
  # can't push the working set to disk swap. nix-daemon spawns builds in
  # child cgroups, so weights set on the slice (not the service) propagate.
  systemd.slices."nix-builds" = {
    description = "Nix builds (background, deprioritized)";
    sliceConfig = {
      CPUWeight = 20;
      IOWeight = 20;
      MemoryHigh = "60%";
      MemoryMax = "85%";
    };
  };
  systemd.services.nix-daemon.serviceConfig = {
    Slice = "nix-builds.slice";
    OOMScoreAdjust = 500;  # prefer killing builds over interactive procs
  };

  # Protect the interactive user session from system-side resource pressure.
  # Mirrors what Fedora's `uresourced` daemon does dynamically — done
  # statically here because this is a single-user box that never switches
  # accounts. Without this, a misbehaving system.slice service can push the
  # user's working set to swap and steal I/O. 2026-05-18 incident:
  # systemd-coredump processing a quickshell crash dump triggered exactly
  # this — 65% iowait, 1.3 GB/s swap-in, load avg 18, ~10 min of unusable
  # desktop. nix-builds.slice was already capped (CPUWeight=20), but the
  # rest of system.slice wasn't, so this is the structural complement.
  systemd.slices."user-1000" = {
    sliceConfig = {
      MemoryLow = "1G";    # protect 1G of working set from reclaim
      CPUWeight = 200;     # 2× default; tips contention toward user
      IOWeight = 200;
    };
  };

  # Cap systemd-coredump's own resource use while it processes a crash.
  # Upstream's unit has Nice=9 but no I/O or memory caps — compressing a
  # multi-hundred-MB Qt/QML core (zstd buffers ~hundreds of MB at default
  # level) pulls the working set into page cache and evicts everything
  # else. Upstream fix is pending streaming-compression rewrite
  # (systemd#29263); cap locally in the meantime. MemoryMax kicks the
  # cgroup OOM if compression genuinely needs >1G — losing the crash
  # dump is strictly better than losing the desktop.
  systemd.services."systemd-coredump@".serviceConfig = {
    CPUWeight = 10;
    IOWeight = 10;
    MemoryHigh = "512M";
    MemoryMax = "1G";
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
