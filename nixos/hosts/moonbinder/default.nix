{ config, pkgs, lib, ... }:

{
  imports = [
    ../../badged.nix
    ../../fw16-speaker-dsp.nix
  ];

  networking.hostName = "moonbinder";

  # TODO: Remove when fixes land upstream (targeting 6.20+). Check:
  #   - LKML: https://lore.kernel.org/linux-wireless/?q=mt7925+deadlock
  #   - Tracker: https://community.frame.work/t/tracking-kernel-panic-from-wifi-mediatek-mt7925-nullptr-dereference/79301
  #   - Patches: https://github.com/zbowling/mt7925
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

  # Use latest stable kernel (6.19.x) — s0ix deep sleep works on 6.19.2+.
  # Previously pinned to 6.17 due to MES hangs, now fixed by the TLB fence patch.
  boot.kernelPackages = pkgs.linuxPackages_latest;

  # Fix for MES (Micro Engine Scheduler) hangs on RDNA 3.5.
  # Unconditional TLB fences tickle KIQ/MES bugs, causing ring buffer saturation
  # → hung tasks → system freeze. This patch makes TLB fences conditional (only
  # for compute/userspace queues). Merged upstream for kernel 7.0.
  # Ref: https://lore.kernel.org/amd-gfx/20260316151636.1122226-1-alexander.deucher@amd.com/
  # Remove once we're on kernel 7.0+.
  boot.kernelPatches = [{
    name = "amdgpu-tlb-fence-rework";
    patch = ../../amdgpu-tlb-fence-rework.patch;
  }];

  # Seamless ethernet↔WiFi failover (like macOS):
  # Both interfaces stay connected simultaneously. Route metrics control which
  # one carries traffic — lower metric = higher priority. When ethernet is
  # unplugged, the kernel routing table already has WiFi routes so traffic
  # fails over instantly (sub-second) with no reconnection needed.
  networking.networkmanager.connectionConfig = {
    "ethernet.route-metric" = "100"; # ethernet preferred when available
    "wifi.route-metric" = "600";     # WiFi as fallback
  };

  # Disable WiFi power saving so the radio stays associated with the AP even
  # when ethernet is active. Without this, WiFi may sleep and need to
  # re-associate on failover, adding seconds of downtime.
  networking.networkmanager.wifi.powersave = false;

  # Graphics (AMD iGPU — Ryzen AI 300 series)
  hardware.graphics.enable = true;

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
  services.udev.extraRules = ''
    ACTION=="add", SUBSYSTEM=="thunderbolt", ATTRS{iommu_dma_protection}=="1", ATTR{authorized}=="0", ATTR{authorized}="1"
  '';

  security.pam.services.greetd.fprintAuth = false;

  # ── Suspend & hibernate ─────────────────────────────────────────
  # s2idle on this platform never reaches deep S0i3 (amd_pmc reports "Last
  # suspend didn't reach deepest state"), so the SoC idles at ~5-10 W instead
  # of ~0.5 W. Suspend-then-hibernate ensures the battery doesn't drain
  # overnight: s2idle runs for 2 hours (enough for quick lid-open-close), then
  # the system hibernates to disk and draws zero power.
  services.logind.settings.Login.HandleLidSwitch = "suspend-then-hibernate";
  systemd.sleep.settings.Sleep.HibernateDelaySec = "2h";

  # Battery / power info (used by ironbar, etc.)
  services.upower.enable = true;

  # Fan control for Framework (using default curves for now)
  # Custom curves from Silverblue backup are in NixLifeboat/fw-fanctrl-config.json
  hardware.fw-fanctrl.enable = true;
}
