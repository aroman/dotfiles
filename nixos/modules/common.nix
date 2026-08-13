{
  config,
  pkgs,
  lib,
  desktop ? true,
  desktopSystemPackages ? [],
  ...
}:

{
  # Boot
  boot.loader.systemd-boot.enable = true;
  boot.loader.systemd-boot.configurationLimit = 20;
  boot.loader.systemd-boot.consoleMode = "5";
  boot.initrd.systemd.enable = true;
  boot.loader.efi.canTouchEfiVariables = true;


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

  # User account
  users.users.aroman = {
    isNormalUser = true;
    description = "aroman";
    extraGroups = [ "wheel" ];
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

    # nix-direnv's `use flake` runs `nix flake archive` after evaluating the
    # shell. That defeats Nix 2.35's lazy flake-source copying and writes the
    # entire source tree to /nix/store for every dirty worktree. Keep
    # nix-direnv's other helpers, but restore a lazy `use flake` implementation.
    direnvrcExtra = ''
      use_flake() {
        local flake_ref="''${1:-.}"
        local flake_uri="''${flake_ref%%#*}"
        local flake_dir="''${flake_uri#path:}"
        local layout_dir profile dev_env

        if [[ "$(nix --extra-experimental-features nix-command eval --raw --expr 'if builtins.compareVersions builtins.nixVersion "2.35" >= 0 then "yes" else "no"')" != yes ]]; then
          log_error "lazy flake activation requires Nix 2.35 or newer"
          return 1
        fi

        if [[ -d "$flake_dir" ]]; then
          watch_file "$flake_dir/flake.nix" "$flake_dir/flake.lock"
        fi

        layout_dir="$(direnv_layout_dir)"
        profile="$layout_dir/flake-profile"
        mkdir -p "$layout_dir"

        if ! dev_env="$(nix --extra-experimental-features 'nix-command flakes' print-dev-env --profile "$profile" "$@")"; then
          return 1
        fi

        eval "$dev_env"
        nix --extra-experimental-features 'nix-command flakes' profile wipe-history --profile "$profile"
      }
    '';
  };

  # OOM protection — kill the biggest offender before the system freezes.
  # Memory pressure can saturate zram compression and spill into slow disk swap
  # long before reclaim fails and the kernel invokes its OOM killer.
  #
  # CAVEAT: earlyoom's conditions are ANDed — it acts only when available
  # memory *and* free swap are both under threshold. "Swap" here is the whole
  # pool from /proc/meminfo (zram + disk swapfile). On a host with a large pool,
  # these percentages arm very late: on wizardtower (39 GiB pool), 10% swap
  # free means ~35 GiB already consumed, deep into the disk swapfile.
  # systemd-oomd below is the primary PSI-driven defense; earlyoom is a late
  # backstop once both available memory and total swap are nearly exhausted.
  # Revisit these thresholds if oomd ever proves insufficient.
  services.earlyoom = {
    enable = true;
    freeMemThreshold = 5;      # SIGTERM when available memory is <5%
    freeSwapThreshold = 10;    # ... and total swap is <10% free
    freeMemKillThreshold = 2;  # SIGKILL when available memory is <2%
    freeSwapKillThreshold = 5; # ... and total swap is <5% free
  };

  # PSI-driven userspace OOM: watch cgroup memory pressure (time-stalled, not
  # free%) and kill whole cgroups before the kernel OOM has to fire. Pairs
  # with earlyoom (PSI handles the "thrashing but RAM not yet empty" case;
  # earlyoom handles the late "available memory and swap nearly gone" case).
  systemd.oomd = {
    enable = true;
    enableUserSlices = true;
    enableRootSlice = true;
    settings.OOM.DefaultMemoryPressureDurationSec = "20s";
  };

  # Let downloaded binaries find the dynamic linker (Prisma, Playwright, etc.)
  programs.nix-ld.enable = true;

  # Allow unfree packages (Spotify, 1Password, Chrome, etc.)
  nixpkgs.config.allowUnfree = true;

  # Core system packages (user packages go in home.nix)
  environment.systemPackages = (with pkgs; [
    android-tools  # adb + fastboot (udev rules handled by systemd 258)
    chafa
    curl
    file
    # herdr is deliberately not here (nor in home.packages) — it's managed
    # imperatively via `nix profile`, pinned to the same tagged release as
    # remote clients, so it can be upgraded independently of a system rebuild.
    git
    lazygit
    lsof
  ]) ++ lib.optionals desktop desktopSystemPackages;

  programs.nh = {
    enable = true;
    flake = "/home/aroman/Projects/dotfiles/nixos";
    # Weekly GC via `nh clean all` instead of nix.gc: root's
    # nix-collect-garbage only prunes profiles under /nix/var/nix/profiles,
    # so per-user profile generations (~/.local/state/nix/profiles) pile up
    # forever and pin their full closures — that once grew the store to
    # ~200G. `nh clean all` prunes every user's profiles and stale gcroots
    # too, then collects.
    clean = {
      enable = true;
      dates = "weekly";
      extraArgs = "--keep-since 14d --keep 3";
    };
  };

  # Nix 2.35 lazily copies flake sources. This is what makes the Direnv
  # override above safe for large, frequently-dirtied Git worktrees.
  nix.package = pkgs.nixVersions.nix_2_35;

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
    # Cap parallelism to leave interactive headroom. Nix's own default is
    # max-jobs=nproc × cores=nproc, i.e. nproc² potential compiler procs.
    #
    # These are the conservative floor, not a considered per-host value —
    # they're deliberately low enough to be safe on the smallest box here.
    # Thread counts differ per machine, so hosts that want the whole CPU
    # override them in hosts/<name>/default.nix; mkDefault is what lets
    # them do that without lib.mkForce.
    #
    # Note this is belt-and-suspenders on top of the SCHED_IDLE + CPUWeight
    # setup below, which is what actually guarantees builds never preempt
    # interactive work. Lowering these buys headroom only in the sense of
    # leaving threads *idle*; it doesn't add responsiveness the scheduler
    # policy isn't already providing.
    max-jobs = lib.mkDefault 2;
    cores = lib.mkDefault 4;
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

  # Hardlink-dedup identical files across store paths.  This had never run
  # here; the first manual pass on 2026-08-05 took /nix/store from 167 GB to
  # 100 GB (66 GB off the filesystem).  Subsequent runs only touch paths added
  # since the last pass, so the daily timer is cheap.
  #
  # Complements `programs.nh.clean` above rather than overlapping it: clean
  # deletes what nothing references any more, optimise deduplicates what
  # survives.  Neither substitutes for the other, and the two failures they
  # fix were both real here — per-user profiles pinning closures (fixed by
  # nh clean) and 67 GB of never-deduplicated files (fixed by this).
  nix.optimise.automatic = true;


  # This value determines the NixOS release from which the default
  # settings for stateful data, like file locations and database versions
  # on your system were taken. It's perfectly fine and recommended to leave
  # this value at the release version of the first install of this system.
  system.stateVersion = "24.11";
}
