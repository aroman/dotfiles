{ lib, ... }:

{
  options.local = {
    headlessDisplay = lib.mkOption {
      type = lib.types.bool;
      default = false;
      description = ''
        Whether this host drives only a virtual/dummy display (e.g. an HDMI
        dummy plug for headless GPU streaming) rather than a real monitor.

        When true, idle-driven monitor power-off is skipped: there is no
        physical display to save power on, and powering off the dummy plug
        tears down the CRTC, which breaks Sunshine's KMS capture path.
      '';
    };
  };
}
