{
  config,
  pkgs,
  lib,
  desktop,
  username,
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
  # Reap sessions whose client vanished without closing the TCP connection —
  # a Mac that slept, a laptop that changed networks. sshd otherwise waits out
  # the kernel's retransmits, and until it does, the dead session still holds
  # its forwarded ports. The opener-tunnel job on the Mac then cannot rebind
  # 47831 and the bridge is down for as long as the corpse lasts. ~90s.
  services.openssh.settings.ClientAliveInterval = 30;
  services.openssh.settings.ClientAliveCountMax = 3;
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
  users.users.${username} = {
    isNormalUser = true;
    description = username;
    extraGroups = [ "wheel" ];
    shell = pkgs.fish;
    # Keep the user systemd instance alive between logins so ssh-agent
    # (programs.ssh.startAgent) survives across SSH disconnects — making
    # `ssh-add` a once-per-boot operation rather than once-per-login.
    linger = true;
  };

  # Enable fish system-wide (needed for it to be a valid login shell)
  programs.fish.enable = true;

  # Agent daemons can exhaust the legacy 1024-descriptor soft limit.
  # Cover login sessions and both systemd managers while retaining the
  # existing hard limit for applications that raise their own soft limit.
  security.pam.loginLimits = [
    { domain = "*"; type = "soft"; item = "nofile"; value = "65536"; }
    { domain = "*"; type = "hard"; item = "nofile"; value = "524288"; }
  ];
  systemd.settings.Manager.DefaultLimitNOFILE = "65536:524288";
  systemd.user.settings.Manager.DefaultLimitNOFILE = "65536:524288";

  programs.direnv = {
    enable = true;
    nix-direnv.enable = true;
    settings.global.hide_env_diff = true;

    # nix-direnv's `use flake` runs `nix flake archive` after evaluating the
    # shell. That defeats Nix 2.35's lazy flake-source copying and writes the
    # entire source tree to /nix/store for every dirty worktree. Keep
    # nix-direnv's other helpers, but restore a lazy `use flake` implementation.
    #
    # Cache the evaluated dev env in the layout dir the way nix-direnv does,
    # keyed on the mtimes of the files the evaluation reads: flake.nix,
    # flake.lock, and whatever they reach through relative path literals (a
    # lockfile the flake parses for a version pin, say). Without a cache every
    # new shell re-runs `nix print-dev-env`, and in a worktree with edits the
    # flake's fingerprint changes with them, so Nix's eval cache misses and
    # the shell waits out a full re-evaluation. A cache hit runs no nix at all.
    #
    # A miss first looks those files' contents up in an index shared by every
    # checkout. Worktrees of one repo mostly evaluate byte-identical envs (a
    # merge of main re-evaluates every worktree it lands in), and re-rooting an
    # env another checkout already built takes ~20ms instead of seconds.
    #
    # Uses nix-direnv's `_nix_import_env` and `_nix_argsum_suffix`, which are
    # in scope because nix-direnv's direnvrc is sourced above this.
    direnvrcExtra = ''
      # Evaluated dev envs, shared by every checkout: one file per content key,
      # holding the nix-shell-env store path that key evaluated to.
      _flake_env_index="''${XDG_CACHE_HOME:-$HOME/.cache}/direnv/flake-envs"

      # Uses of `self` that reach only the flake's outputs, never its source tree:
      # `self.packages` and kin, and `self` as a formal or lambda argument. Any
      # other use (`self + "/x"`, `self.rev`, `src = self;`) makes the whole tree
      # an input, so a form missing here costs sharing, not correctness.
      _flake_env_self_ok='\bself[[:space:]]*\.[[:space:]]*(packages|legacyPackages|devShells|checks|apps|formatter|lib|overlays|nixosModules|darwinModules|homeModules|nixosConfigurations|templates|inputs)\b|\bself[[:space:]]*[,?:}@]'

      _flake_env_nix() {
        nix --extra-experimental-features 'nix-command flakes' "$@"
      }

      # Write the remaining arguments as lines to $1 through a temp file: two
      # terminals loading at once would otherwise race, and a reader could see a
      # half-written file. Rename within one directory is atomic.
      _flake_env_put() {
        local dest=$1
        shift
        if (( $# )); then printf '%s\n' "$@"; fi > "$dest.$$"
        mv -f "$dest.$$" "$dest"
      }

      # Set _flake_env_deps to the files evaluating the flake at $1 reads:
      # flake.lock, flake.nix, and every file reachable from it through relative
      # path literals, each resolved against the file it appears in. Clear
      # _flake_env_keyable when those files don't bound the evaluation: a literal
      # naming a directory (`./.`, `import ./nix`, `./''${x}`), or `self` used as
      # source.
      _flake_env_scan() {
        local root=$1 file text ref path
        local -a queue=("$root/flake.nix")
        local -A seen=()
        _flake_env_deps=("$root/flake.lock")
        _flake_env_keyable=1
        while (( ''${#queue[@]} )); do
          file=''${queue[0]}
          queue=("''${queue[@]:1}")
          [[ -z "''${seen[$file]-}" ]] || continue
          seen[$file]=1
          _flake_env_deps+=("$file")
          [[ "$file" == *.nix && -f "$file" ]] || continue
          # Drop comments, so prose like "see ./docs" isn't read as a path.
          text="$(sed 's/#.*//' "$file")"
          # Interpolation first: stripping `self}` below would hide "''${self}".
          if grep -Eq '\$\{[[:space:]]*(inputs\.)?self\b' <<<"$text" ||
             sed -E "s/$_flake_env_self_ok//g" <<<"$text" | grep -qw self; then
            _flake_env_keyable=0
          fi
          while IFS= read -r ref; do
            # Lexically, as Nix resolves path literals.
            path="$(expand_path "''${ref#[!.]}" "''${file%/*}")"
            if [[ -d "$path" ]]; then
              _flake_env_keyable=0
            else
              queue+=("$path")
            fi
          done < <(grep -oE '(^|[^A-Za-z0-9._+/-])\.\.?/[A-Za-z0-9._+/-]*' <<<"$text")
        done
      }

      # Hash _flake_env_deps' contents under their paths relative to $1, plus the
      # remaining arguments, so identical checkouts anywhere share a key.
      _flake_env_key() {
        local root=$1 dep key
        shift
        key="$({
          printf '%s\n' "$@"
          for dep in "''${_flake_env_deps[@]}"; do
            printf '%s ' "''${dep#"$root"/}"
            if [[ -f "$dep" ]]; then sha256sum < "$dep"; else echo absent; fi
          done
        } | sha256sum)"
        printf '%s\n' "''${key%% *}"
      }

      use_flake() {
        local flake_ref="''${1:-.}"
        local flake_uri="''${flake_ref%%#*}"
        local flake_dir="''${flake_uri#path:}"
        local layout_dir profile profile_rc profile_deps dev_env root
        local nix_id key="" index_file="" env_path changed=0
        local -a _flake_env_deps=() links
        local _flake_env_keyable=0

        layout_dir="$(direnv_layout_dir)"
        # Suffix the cache by flake expression, so `use flake` and
        # `use flake .#mobile` in one directory cannot read each other's env.
        profile="$layout_dir/flake-profile$(_nix_argsum_suffix "''${1-}")"
        profile_rc="$profile.rc"
        profile_deps="$profile.deps"
        mkdir -p "$layout_dir"

        local stale=0 file
        if [[ ! -e "$profile" || ! -e "$profile_rc" || ! -e "$profile_deps" ]] ||
           [[ -n "''${_nix_direnv_force_reload-}" ]]; then
          stale=1
        else
          mapfile -t _flake_env_deps < "$profile_deps"
          for file in "''${_flake_env_deps[@]}" "$HOME/.direnvrc" "$HOME/.config/direnv/direnvrc"; do
            if [[ -e "$file" && "$file" -nt "$profile_rc" ]]; then
              stale=1
            fi
          done
        fi

        if (( stale )); then
          _flake_env_deps=()
          if [[ -d "$flake_dir" ]]; then
            root="$(realpath -- "$flake_dir")"
            _flake_env_scan "$root"
            # Watch now, so the returns below still reload once an input is fixed.
            watch_file "''${_flake_env_deps[@]}"
          fi

          # Assert the Nix version only on a miss: a hit invokes no nix at all,
          # and an older nix would merely fall back to copying the whole source
          # tree — slow, not wrong. The version and system also key the index.
          nix_id="$(_flake_env_nix eval --impure --raw --expr 'if builtins.compareVersions builtins.nixVersion "2.35" >= 0 then builtins.nixVersion + " " + builtins.currentSystem else ""')"
          if [[ -z "$nix_id" ]]; then
            log_error "lazy flake activation requires Nix 2.35 or newer"
            return 1
          fi

          # Only a bare flake ref is keyable: flags like --impure or
          # --override-input feed the evaluation from outside the key.
          if (( _flake_env_keyable )) && [[ $# -le 1 && "''${1-}" != -* ]]; then
            key="$(_flake_env_key "$root" "$nix_id" "''${1-}")"
            index_file="$_flake_env_index/$key"
          fi

          # A `*-env` store path makes print-dev-env skip evaluation; any failure
          # falls through to a real one. A forced reload never trusts the index.
          if [[ -n "$index_file" && -z "''${_nix_direnv_force_reload-}" && -r "$index_file" ]] &&
             read -r env_path < "$index_file" &&
             [[ "$env_path" == /nix/store/*-env && -e "$env_path" ]] &&
             dev_env="$(_flake_env_nix print-dev-env --profile "$profile" "$env_path" 2>/dev/null)"; then
            :
          elif dev_env="$(_flake_env_nix print-dev-env --profile "$profile" "$@")"; then
            if [[ -n "$index_file" ]]; then
              # The key hashed the inputs before evaluating; record the env only
              # if they still hash the same, i.e. nothing changed mid-evaluation.
              _flake_env_scan "$root"
              env_path="$(readlink -f "$profile")"
              if [[ "$(_flake_env_key "$root" "$nix_id" "''${1-}")" == "$key" &&
                    "$env_path" == /nix/store/*-env ]]; then
                mkdir -p "$_flake_env_index"
                _flake_env_put "$index_file" "$env_path"
              else
                changed=1
              fi
            fi
          elif [[ -e "$profile_rc" ]]; then
            # A tracked file can be mid-edit (a half-written package.json is not
            # JSON). Keep the last good env rather than handing out a shell with
            # no toolchain, and say so.
            log_error "evaluating the devShell failed; falling back to the cached environment"
            dev_env=""
          else
            return 1
          fi

          if [[ -n "$dev_env" ]]; then
            _flake_env_put "$profile_rc" "$dev_env"
            _flake_env_put "$profile_deps" "''${_flake_env_deps[@]}"
            # An input changed while evaluating: backdate the rc so the next
            # load re-evaluates instead of trusting it.
            if (( changed )); then
              touch -d @0 "$profile_rc"
            fi
            # Nix adds a generation only when the env changes, so there is
            # often no history to wipe; skip the nix call then.
            links=("$profile"-*-link)
            if (( ''${#links[@]} > 1 )); then
              _flake_env_nix profile wipe-history --profile "$profile"
            fi
          fi
        fi

        watch_file "''${_flake_env_deps[@]}" "$profile_rc"
        # nh clean ages .direnv GC roots by their links' mtimes and prunes any
        # that look abandoned. Refresh them on every load, as nix-direnv does.
        touch -c -h "$profile" "$profile"-*-link || true
        # nix-direnv's importer, not a bare `eval`: it restores TMPDIR and
        # friends (print-dev-env points them at a throwaway build dir it then
        # leaves behind) and de-duplicates XDG_DATA_DIRS.
        _nix_import_env "$profile_rc"
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
    # herdr is deliberately not here (nor in home.packages) — it's imperative
    # so it can move without a system rebuild:
    #
    #   nix profile remove herdr
    #   nix profile add github:NixOS/nixpkgs/nixos-unstable#herdr
    #
    # nixpkgs, not `github:herdrdev/herdr/vX.Y.Z` — that flake declares no
    # substituters and so builds from source on every host. Upgrade all
    # machines together, since the wire protocol requires an exact
    # client/server match.
    #
    # Swapping the binary does not touch a running server. If the new client
    # still speaks the old server's protocol, everything keeps working and
    # `herdr status` just reports `server_binary_stale: yes`. `herdr --remote
    # <host> --handoff` only kicks in when the protocols are incompatible —
    # against a compatible server it attaches normally and does nothing — and
    # `herdr update --handoff` is disabled for Nix installs. So the server
    # only picks up a compatible release when it restarts (`systemctl --user
    # restart herdr`, which ends pane processes; agents with resume hooks
    # come back), and is handed off live only across a protocol bump.
    git
    lazygit
    lsof
  ]) ++ lib.optionals desktop desktopSystemPackages;

  programs.nh = {
    enable = true;
    flake = "/home/${username}/Projects/dotfiles/nixos";
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
      "https://vicinae.cachix.org"
    ];
    trusted-public-keys = [
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
