{ pkgs, ... }:

{
  # opener-bridged, as the Mac runs it under launchd: `xdg-open` on these hosts
  # opens here when this is the machine you last touched.  Bound to the
  # graphical session, so the tunnels exist exactly while there is a display.
  home.packages = [ pkgs.glib.bin ];  # gio, which it opens URLs with

  systemd.user.services.opener-bridged = {
    Unit = {
      Description = "Open URLs from remote hosts on this display";
      After = [ "graphical-session.target" ];
      PartOf = [ "graphical-session.target" ];
    };
    Service = {
      ExecStart = "${pkgs.python3}/bin/python3 ${../../local/bin/opener-bridged} wizardtower fairycastle";
      Restart = "always";
      RestartSec = 5;
    };
    Install.WantedBy = [ "graphical-session.target" ];
  };
}
