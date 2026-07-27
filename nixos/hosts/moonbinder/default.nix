{ config, pkgs, lib, ... }:

{
  imports = [
    ../../badged.nix
    ../../fw16-speaker-dsp.nix
  ];

  networking.hostName = "moonbinder";

  # TODO: Remove when fixes land upstream. Still NOT upstream as of 7.1.4 AND
  # mainline master (verified 2026-07-27 by reading mt7925/{mac,main,pci}.c
  # directly, not the list archives: mt7925_mlo_pm_iter still takes the mutex
  # itself, mt7925_mlo_pm_work still doesn't, no bss_conf NULL checks anywhere).
  # zbowling's series is parked at v7 and the repo has had no commit since
  # 2026-01-29; the locking slice we carry is contested — maintainers want the
  # root fix in mac80211 core, not driver-local NULL checks. ROC-deadlock half
  # already landed (7.0.10) and is not in our patch. Check:
  #   - LKML: https://lore.kernel.org/linux-wireless/?q=mt7925+deadlock
  #   - Tracker: https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301
  #   - Patches: https://github.com/zbowling/mt7925
  #   - Fastest upstream check (no Anubis wall, unlike git.kernel.org):
  #     curl -s https://raw.githubusercontent.com/torvalds/linux/master/\
  #     drivers/net/wireless/mediatek/mt76/mt7925/main.c | grep -A12 mlo_pm_work
  #   - To verify after reboot: modinfo mt7925e | grep filename
  #     (should show updates/mt7925e.ko.xz, not kernel/drivers/...)
  #
  # MT7925 WiFi driver: patched out-of-tree module (deadlock + mutex fixes).
  # Fixes a kernel deadlock in mt7925_roc_abort_sync that hangs the entire
  # network subsystem during AP roaming. Also adds mutex protection in
  # reset/suspend/PM paths and NULL checks for MLO link state transitions.
  boot.extraModulePackages = [
    (pkgs.callPackage ../../mt7925-patched.nix {
      kernel = config.boot.kernelPackages.kernel;
    })
  ];

  # Latest stable kernel — 7.1.4 as of 2026-07-27.
  #
  # Historical floors, both long since cleared, kept so the reason for tracking
  # `latest` rather than the LTS is on record:
  #   - 6.19.2  s0ix deep sleep started working on this platform
  #   - 6.19.11 MES hang fix (TLB fence rework) backported to stable, which is
  #             what let us drop the downstream patch we used to carry
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Seamless ethernet↔WiFi failover (like macOS):
  # Both interfaces stay connected simultaneously. Route metrics control which
  # one carries traffic — lower metric = higher priority. When ethernet is
  # unplugged, the kernel routing table already has WiFi routes so traffic
  # fails over instantly (sub-second) with no reconnection needed.
  networking.networkmanager.settings = {
    # Real wired ethernet (docks) wins by default — but exclude the iPhone's
    # USB-tether interface, which also presents as ethernet and would otherwise
    # grab metric 100 and hijack the default route the instant the phone is
    # plugged in. ipheth is the Apple-tether-only driver, so excluding it never
    # affects a dock's wired NIC.
    "connection-ethernet" = {
      "match-device" = "type:ethernet,except:driver:ipheth";
      "ipv4.route-metric" = 100;
    };
    "connection-wifi" = {
      "match-device" = "type:wifi";
      "ipv4.route-metric" = 600;
    };
    # iPhone USB tether: bottom of the fallback order — carries traffic only
    # when both wired and Wi-Fi are down. Metric 700 sits just below Wi-Fi (600).
    # ipv6 is set explicitly because ipheth is an ethernet-type link and would
    # otherwise default to metric 100 on v6 and win there.
    "connection-iphone-tether" = {
      "match-device" = "driver:ipheth";
      "ipv4.route-metric" = 700;
      "ipv6.route-metric" = 700;
    };
  };

  # Disable WiFi power saving so the radio stays associated with the AP even
  # when ethernet is active. Without this, WiFi may sleep and need to
  # re-associate on failover, adding seconds of downtime.
  networking.networkmanager.wifi.powersave = false;

  # Use iwd instead of wpa_supplicant as NetworkManager's WiFi backend.
  #
  # Drove this by observing wpa_supplicant doing classic full re-association
  # on every BTM-driven roam (eero "Client Steering" pushing us between two
  # APs every few minutes — confirmed in journal: SME auth + full association
  # + EAPOL 4-way handshake each time, no FT). 200-500ms gap per roam was
  # killing long-lived HTTP/WebSocket connections (Claude Code, etc.).
  #
  # eero Client Steering is now also off (settled the immediate problem), but
  # iwd is the right long-term backend on this hardware:
  #   - native 802.11k/v/r evaluation: declines marginal BTM requests rather
  #     than blindly accepting (closer to macOS roaming behavior)
  #   - faster connect/resume — less protocol round-tripping
  #   - smaller, more modern codebase (~30k LOC vs ~200k for wpa_supplicant)
  #   - per-connection MAC randomization defaults
  #   - actively developed; wpa_supplicant is essentially in maintenance mode
  #
  # NetworkManager connection profiles in /etc/NetworkManager/system-connections/
  # are backend-agnostic, so saved networks (Larnathord, etc.) keep working
  # across the switch. No reconfig needed.
  networking.wireless.iwd.enable = true;
  networking.networkmanager.wifi.backend = "iwd";

  # Per-connection tweaks NOT captured declaratively (NM stores these in
  # /etc/NetworkManager/system-connections/, which survives rebuilds but not
  # reimages). Re-apply after a reimage:
  #
  #   nmcli connection modify Larnathord 802-11-wireless.band a
  #   nmcli connection modify "Wired connection 1" connection.id "TS4 Ethernet"
  #   nmcli connection modify "Wired connection 2" connection.id "iPhone Hotspot"
  #
  # `band=a` restricts Larnathord to 5/6 GHz, skipping 2.4 GHz scan time on
  # connect. Safe because all home APs broadcast 5+6 GHz.
  #
  # The two renames are cosmetic — NM auto-creates "Wired connection 1" (the TS4
  # dock's onboard Intel I225 2.5GbE, interface enp95s0) and "Wired connection 2"
  # (the ipheth iPhone tether, interface eth0); renaming gives friendly menu
  # labels. The route ordering is handled declaratively via the route-metric
  # match-device rules above, so naming has no functional effect. ("TS4 Ethernet"
  # is TS4-specific — the TS3 at work presents a different interface name.)

  # Graphics (AMD iGPU — Ryzen AI 300 series)
  hardware.graphics.enable = true;

  # Disable the NVIDIA dGPU entirely — blacklist nouveau so only the AMD iGPU
  # is used. The NVIDIA GPU will power down automatically via PCIe ASPM/runtime PM
  # when no driver binds to it.
  boot.blacklistedKernelModules = [ "nouveau" "nvidia" "nvidia_drm" "nvidia_modeset" ];

  # Power tuning identified via powertop + amd-s2idle analysis.
  # Note: snd_hda_intel power_save is already enabled at kernel-config level
  # (CONFIG_SND_HDA_POWER_SAVE_DEFAULT=10 in nixpkgs kernel), so no modprobe
  # override is needed for it.
  boot.kernel.sysctl = {
    # Default 500 (5s). Raising to 15s lets NVMe stay parked longer between
    # small writes; max dirty-page age is still bounded by dirty_expire (30s).
    "vm.dirty_writeback_centisecs" = 1500;
    # Hard-lockup detector fires periodic NMIs on every core, preventing the
    # deepest idle. Disable on a daily-driver laptop where we'd reboot anyway.
    "kernel.nmi_watchdog" = 0;
    # Faster TCP failure detection for laptop interface churn (dock unplug,
    # wifi roam). Defaults assume server-room stable networks where brief
    # blips shouldn't kill long sessions. Here, sockets bound to a gone-away
    # source IP (e.g. ethernet via TS4) would otherwise hang for ~15min
    # before erroring, stalling apps that would've retried cleanly.
    #   retries2=8  → ~100s ceiling (RFC 1122 minimum) instead of ~924s
    #   keepalive   → detect dead idle sockets in ~2min instead of ~2h
    # Tradeoff: long-running TCP (SSH, big uploads) won't survive a real
    # 30-90s outage. Acceptable for this workload.
    "net.ipv4.tcp_retries2" = 8;
    "net.ipv4.tcp_keepalive_time" = 60;
    "net.ipv4.tcp_keepalive_intvl" = 10;
    "net.ipv4.tcp_keepalive_probes" = 6;
  };

  # Firmware updates (Framework)
  services.fwupd.enable = true;

  # Disable the airplane mode key (FW16 keyboard wireless radio button).
  # It triggers rfkill at the kernel level and kills WiFi/Bluetooth with no undo UX.
  # Remap its HID scancode (Generic Desktop page 0x01, usage 0xC6) to nothing.
  services.udev.extraHwdb = ''
    evdev:input:b0003v32ACp0012*
      KEYBOARD_KEY_100c6=reserved
  '';

  # 1Password (NixOS module sets up browser extension socket + polkit)
  programs._1password.enable = true;
  programs._1password-gui = {
    enable = true;
    polkitPolicyOwners = [ "aroman" ];
  };

  # Thunderbolt: auto-authorize devices on connect.
  # Without a full DE (GNOME/KDE), there's no GUI prompt for Thunderbolt auth,
  # so USB tunneling through docks (e.g. CalDigit TS3 Plus) won't work without
  # explicit authorization. This udev rule auto-authorizes any Thunderbolt device,
  # but only when IOMMU DMA protection is active — which means the hardware itself
  # prevents unauthorized memory access, making the software security level redundant.
  # Load uinput at early boot so /dev/uinput exists with the udev rule
  # applied before user services (vicinae, voxtype) start — otherwise
  # they race the on-demand module load and silently disable paste.
  boot.kernelModules = [ "uinput" ];

  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="thunderbolt", ATTRS{iommu_dma_protection}=="1", ATTR{authorized}=="0", ATTR{authorized}="1"
    KERNEL=="uinput", SUBSYSTEM=="misc", GROUP="input", MODE="0660"

    # NVIDIA dGPU: enable PCI runtime PM so the GPU powers down when no driver is bound.
    # The kernel module blacklist above prevents nvidia/nouveau from loading, but without
    # this rule the GPU sits in PCI D0 (full power) drawing several watts for nothing.
    ACTION=="add", SUBSYSTEM=="pci", ATTR{vendor}=="0x10de", ATTR{class}=="0x030000", ATTR{power/control}="auto"
  '';

  security.pam.services.greetd.fprintAuth = false;

  # ── Suspend & hibernate ─────────────────────────────────────────
  #
  # Power management strategy: suspend-then-hibernate.
  #
  # When the lid closes:
  #   1. System enters s2idle (S0ix deep sleep, ~0.5 W)
  #   2. After HibernateDelaySec, system hibernates to disk (0 W)
  #   3. On lid open, resumes from whichever state it's in
  #
  # Why not just s2idle? Two reasons:
  #   - The expansion bay PCIe switch (GPP0.SWUS) has a BIOS bug that sometimes
  #     prevents reaching the deepest S0i3 state. When that happens, the SoC
  #     idles at ~5-10 W instead of ~0.5 W. Hibernate is the safety net.
  #   - Even perfect s2idle still draws some power. For overnight/travel,
  #     hibernate means zero battery drain once the delay elapses.
  #
  # Requires: 32 GiB swap file (see hardware-configuration.nix) and
  #           boot.resumeDevice + resume_offset for hibernate resume.
  #
  # Diagnostics (after a suspend cycle):
  #   journalctl -k | grep -iE 'amd_pmc|constraint|LPI|s2idle|deepest'
  #   cat /sys/power/suspend_stats/last_hw_sleep  (should be >0)
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep.HibernateDelaySec = "4h";

  # Hibernate by powering off (ACPI S5) rather than entering ACPI S4.
  #
  # Hibernation is entirely the kernel's doing — snapshot RAM, write it to the
  # swapfile, have the initrd read it back next boot. The firmware is only
  # involved in *how the machine switches off*, and that choice is what was
  # broken here. systemd's default HibernateMode is "platform shutdown": it
  # tries "platform" first, which enters S4 via ACPI _PTS and leaves the
  # firmware knowing the OS hibernated, so the next power-on takes a distinct
  # S4-resume boot path. That path relocates an 8 KiB E820_TYPE_ACPI block in
  # low memory (UEFI boot-services heap residue; every table we actually parse
  # lives in the stable region up at 0x79f7f000). hibernation_e820_save()
  # checksums e820_table_firmware byte-for-byte (CRC32 now, MD5 when the check
  # landed in 62a03defeabd), so arch_hibernation_header_restore() returns
  # -EINVAL and the image is thrown away:
  #
  #   Hibernate inconsistent memory map detected!
  #   PM: hibernation: Image mismatch: architecture specific data
  #   PM: hibernation: resume failed (-1)
  #
  # The result looks exactly like a flat battery: the image writes fine, the
  # machine cold-boots, the session is gone. Broken 2026-04-25 (6.19.11 ->
  # 7.0.1) through 2026-07-26, ~14 lost sessions.
  #
  # "shutdown" skips S4 entirely — a plain power-off, so the firmware sees an
  # ordinary shutdown and the next boot is an ordinary cold boot, which
  # reproduces the map byte-for-byte. Both modes are full hibernation at ~0 W;
  # only the firmware's bookkeeping differs. This is systemd's own fallback
  # mode, not a workaround.
  #
  # The underlying non-determinism is an Insyde UEFI trait, not a kernel bug —
  # the check exists because a page frame from the hibernated kernel landing in
  # the resume kernel's unmapped region would panic. Anything that perturbs
  # pre-kernel EFI allocations can tip it over: Framework 13 hit the same error
  # via GRUB's EFI pool allocations and fixed it by moving to systemd-boot
  # (which we already use, hence S4 being the only remaining amplifier), and
  # System76 hit it purely from charging over barrel vs USB-C. Expect the dock
  # to be capable of the same. No kernel parameter disables the check, and
  # memmap= doesn't help (it edits e820_table, not the firmware copy).
  # Ref: https://community.frame.work/t/framework-16-with-ryzen-ai-and-nvidia-graphics-fails-to-hibernate/82648
  #
  # To verify a resume, grep the journal for 'hibernation exit' and the
  # 'Timekeeping suspended for N seconds' line (which is how long it was really
  # off) — never 'Image signature found', which the initrd kernel logs into a
  # ring buffer that is discarded the moment the image takes over, making
  # successes invisible. A successful resume also leaves `journalctl
  # --list-boots` showing one boot, not two, because the restored kernel *is*
  # the original one.
  systemd.sleep.settings.Sleep.HibernateMode = "shutdown";

  # MT7925 WiFi firmware doesn't survive hibernate. After power-off, the
  # firmware state is gone, and the driver's restore path hits an MCU timeout
  # ("Message 00020002 timeout") leaving the interface stuck in DOWN/DORMANT.
  # The upstream hibernate restore callback (commit d54424fbc53b) exists in
  # 6.19 but doesn't recover reliably. This is a known community-wide issue
  # across MT7921/MT7925 — the standard workaround is reloading the module.
  # Ref: https://community.frame.work/t/round-2-framework-16-fails-to-resume-from-hibernate/75532
  # Remove once MediaTek fixes the firmware reinit path upstream.
  # Upstream check 2026-07-27: still not fixed. mt7925/pci.c in mainline is
  # unchanged from 7.1.4 on this path apart from an IRQ-mask refactor in
  # _mt7925_pci_resume() — .restore still routes to the same MCU handshake
  # that times out, so the module reload below is still the only recovery.
  # Runs after ANY resume (s2idle or hibernate). After hibernate, WiFi is
  # broken and needs a full module reload. After s2idle, WiFi is fine so we
  # skip the reload by checking interface state first.
  # Uses the same After pattern as NixOS's built-in post-resume.service:
  # After=systemd-*.service ensures we run AFTER resume, not before sleep.
  systemd.services.mt7925-hibernate-fixup = {
    description = "Reload MT7925 WiFi module if broken after resume";
    after = [
      "systemd-suspend.service"
      "systemd-hibernate.service"
      "systemd-hybrid-sleep.service"
      "systemd-suspend-then-hibernate.service"
    ];
    wantedBy = [ "sleep.target" ];
    serviceConfig.Type = "oneshot";
    script = ''
      # After s2idle, WiFi is fine (state UP) — skip reload.
      # After hibernate, WiFi is stuck (state DOWN/DORMANT) — reload.
      if ${pkgs.iproute2}/bin/ip link show wlp192s0 2>/dev/null | grep -q "state UP"; then
        echo "WiFi is UP, skipping reload"
        exit 0
      fi
      echo "WiFi is not UP, reloading mt7925e module"
      ${pkgs.kmod}/bin/modprobe -r mt7925e || true
      sleep 1
      ${pkgs.kmod}/bin/modprobe mt7925e
    '';
  };

  # Battery / power info (used by ironbar, etc.)
  services.upower.enable = true;

  # Fan control for Framework (using default curves for now)
  # Custom curves from Silverblue backup are in NixLifeboat/fw-fanctrl-config.json
  hardware.fw-fanctrl.enable = true;
  hardware.fw-fanctrl.package = pkgs.fw-fanctrl.overrideAttrs (prev: {
    patches = (prev.patches or [ ]) ++ [
      ../../patches/fw-fanctrl-silence-ectool-stderr.patch
    ];
  });

  # ── Sunshine (remote desktop streaming) ──────────────────────────
  # Streams the desktop to Moonlight clients. VAAPI for hardware-accelerated
  # encoding on the Radeon 860M (Krackan Point, VCN 4.x — H.264/HEVC/AV1).
  #
  # capture = "wlr": uses zwlr_screencopy_manager_v1, which niri implements.
  # KMS capture (used on wizardtower) returns 0x0 plane resolution against
  # niri's atomic modesetting on AMD, so wlr is the working path here.
  # uinput rule + input group are already configured above / in common.nix.
  # Disabled 2026-07-25: never actually used remotely from this host (the
  # openFirewall note below said as much), and it's a permanently-listening
  # service holding CAP_SYS_ADMIN for no benefit. Costs no battery — it burned
  # 0 s of CPU across a 2 h uptime — this is purely about not running a server
  # we don't use. Flip back to true to restore; the capture/encoder settings
  # below are correct for this hardware and should not be changed (see the
  # wlr-vs-KMS note above).
  services.sunshine = {
    enable = false;
    autoStart = true;
    capSysAdmin = true; # still recommended for full Wayland capture support
    # NixOS's tailscale module only adds tailscale0 to trustedInterfaces when
    # useRoutingFeatures is "server"/"both"; on the default "client" the host
    # firewall fully applies to tailnet traffic. Sunshine here isn't currently
    # used remotely — if that changes, add per-interface allow rules like the
    # tailscale0 block in nixos/hosts/wizardtower/default.nix.
    openFirewall = false;
    settings = {
      encoder = "vaapi";
      capture = "wlr";
      origin_web_ui_allowed = "wan"; # allow access from Tailscale IPs
    };
  };
}
