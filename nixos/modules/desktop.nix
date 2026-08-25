{ config, pkgs, lib, inputs, username, ... }:

{
  # Networking
  networking.networkmanager.enable = true;

  # iPhone USB tethering — runs usbmuxd + libimobiledevice and installs udev
  # rules so the ipheth kernel driver exposes the phone as a USB Ethernet
  # interface that NetworkManager can DHCP on. More stable than Wi-Fi hotspot
  # (no radio jitter) and charges the phone at the same time.
  services.usbmuxd.enable = true;

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

        # Every external binary is pinned. nm-dispatcher runs this with a
        # minimal PATH and a missing one fails *silently*: an unresolved
        # `awk` left gw empty, so the script hit the IPv4-only branch below,
        # flushed the chain and exited 0 on every single event. The RA filter
        # this whole block exists to install has therefore never actually
        # been installed — fail-open, unnoticed, since at least 2026-05-25.
        NFT=${pkgs.nftables}/bin/nft
        IP=${pkgs.iproute2}/bin/ip
        AWK=${pkgs.gawk}/bin/awk
        SLEEP=${pkgs.coreutils}/bin/sleep

        flush_chain() {
          $NFT flush chain ip6 ra-filter input 2>/dev/null || true
        }

        case "$ACTION" in
          up|dhcp6-change)
            # Wait briefly for the IPv6 default route to land via SLAAC.
            gw=""
            for _ in 1 2 3 4 5 6 7 8 9 10; do
              gw=$($IP -6 route show default dev "$IFACE" 2>/dev/null \
                | $AWK '/^default via/ {print $3; exit}')
              [ -n "$gw" ] && break
              $SLEEP 1
            done
            # IPv4-only network (no v6 gateway) — leave RAs unfiltered.
            [ -z "$gw" ] && { flush_chain; exit 0; }

            # Resolve gateway link-local → MAC via the neighbor table.
            mac=""
            for _ in 1 2 3 4 5; do
              mac=$($IP -6 neigh show "$gw" dev "$IFACE" 2>/dev/null \
                | $AWK '/lladdr/ {print $5; exit}')
              [ -n "$mac" ] && break
              $SLEEP 1
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

  # Desktop-only groups. Each is created by an option in this module; keep
  # these out of the headless base so activation cannot reference missing groups.
  users.users.${username}.extraGroups = [ "networkmanager" "video" "input" "i2c" "audio" "kvm" "dialout" ];

  programs.dconf.enable = true;

  # Polkit (needed by 1Password, niri, etc.)
  security.polkit.enable = true;
  # Disable niri-flake's bundled KDE polkit agent — noctalia has its own, and
  # only one agent can hold the registration (see nixos/noctalia.nix).
  systemd.user.services.niri-flake-polkit.enable = false;

  # Owns the `uinput` group that the wrapper below setgids to. This MUST be
  # declared explicitly: it used to arrive transitively via services.sunshine,
  # and when sunshine was disabled on moonbinder (62993a3) the group vanished.
  # security.wrappers then failed `chown root:uinput`, and because the wrapper
  # script runs under `set -e` it aborted before creating /run/wrappers/bin at
  # all — so pam_unix could not exec /run/wrappers/bin/unix_chkpwd and every
  # PAM stack (user@, greetd, kmscon) failed, leaving the host unloggable.
  # One missing group takes down the entire login path; do not rely on another
  # module to provide it.
  hardware.uinput.enable = true;

  # Vicinae 0.21+ expects its input-injection helper at
  # /run/wrappers/bin/vicinae-input-server with elevated access so it can
  # open /dev/uinput. Upstream's installer applies cap_dac_override=ep, but
  # that's a global DAC bypass — way broader than this needs. Since
  # /dev/uinput is group `uinput` (see hardware.uinput above), setgid'ing the
  # wrapper to that group gives the helper exactly the access it needs and
  # nothing else.
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

  # LocalSend
  programs.localsend.enable = true;

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

  _module.args.desktopSystemPackages = with pkgs; [
    xwayland-satellite  # X11 support for niri — auto-spawned on demand
  ];
}
