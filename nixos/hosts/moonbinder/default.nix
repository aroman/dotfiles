{ config, pkgs, pkgs-kernel, lib, ... }:

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

  # Workaround: MES (Micro Engine Scheduler) firmware hangs on RDNA 3.5.
  # Kernel 6.18+/6.19+ have an unresolved amdgpu bug where MES stops responding
  # (ring buffer full → hung tasks → total system freeze requiring REISUB).
  # Pinning to 6.17 from an older nixpkgs avoids the regression entirely.
  # Remove this (and nixpkgs-kernel flake input) once the fix lands upstream.
  # Tracker: https://community.frame.work/t/attn-critical-bugs-in-amdgpu-driver-included-with-kernel-6-18-x-6-19-x/79221
  boot.kernelPackages = pkgs-kernel.linuxPackages_6_17;

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

  # Battery / power info (used by ironbar, etc.)
  services.upower.enable = true;

  # Fan control for Framework (using default curves for now)
  # Custom curves from Silverblue backup are in NixLifeboat/fw-fanctrl-config.json
  hardware.fw-fanctrl.enable = true;
}
