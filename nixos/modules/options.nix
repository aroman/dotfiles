{ lib, ... }:

{
  options.local = {
    headlessDisplay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this host drives only a virtual/dummy display (e.g. an HDMI
        dummy plug for headless GPU streaming) rather than a real monitor.

        When true, the whole idle/lock stack is skipped — not just monitor
        power-off — because none of it has anything to act on:

          - Monitor power-off: there is no physical display to save power
            on, and powering off the dummy plug tears down the CRTC, which
            breaks Sunshine's KMS capture path.

          - Lock before sleep: a headless streaming host does not suspend
            (wizardtower's /sys/power/suspend_stats has read 0 success /
            0 fail for its entire logged history), and noctalia registers
            its own "Lock before sleep" logind delay inhibitor regardless.

          - Idle session lock: locking a headless box means a lock screen
            reachable only over the Sunshine stream, whose polkit agent
            drives an fprintd conversation with no reachable reader. The
            lockout risk outweighs the benefit; remote access is already
            gated by tailnet-only Sunshine pairing and key-only SSH.

        Set this per host in nixos/hosts/<host>/default.nix. Hosts with a
        real panel (laptops especially, where lid-close suspend makes
        lock-before-sleep load-bearing) must leave it false.
      '';
    };
  };
}
