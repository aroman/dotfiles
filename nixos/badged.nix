# Badged — GTK4 polkit authentication agent with fprintd fingerprint support.
# Not in nixpkgs yet. Upstream: https://github.com/jfernandez/badged
#
# Why badged instead of soteria?
#   Soteria doesn't handle the fprintd PAM conversation, so fingerprint auth
#   silently fails and you always get a password prompt. Badged delegates to
#   polkit-agent-helper-1 which drives PAM directly, so pam_fprintd works.
#
# NixOS quirks (two things need fixing):
#
#   1. Path patch: badged hardcodes /usr/lib/polkit-1/polkit-agent-helper-1.
#      On NixOS that path doesn't exist. We substituteInPlace to point at
#      /run/wrappers/bin/polkit-agent-helper-1 instead.
#
#   2. Setuid wrapper: polkit 127 switched to socket-activated helpers, so
#      NixOS no longer makes the helper binary setuid. But badged spawns it
#      directly as a child process, which requires setuid root (the helper
#      needs to do PAM auth). We create a setuid copy via security.wrappers.
{ pkgs, ... }:

let
  badged = pkgs.rustPlatform.buildRustPackage {
    pname = "badged";
    version = "0.1.0";

    src = pkgs.fetchFromGitHub {
      owner = "jfernandez";
      repo = "badged";
      rev = "v0.1.0";
      hash = "sha256-KsrQwM9h0pNmbk9wVNc5F094+XobAB6cDMdZmcoJ79o=";
    };

    cargoHash = "sha256-PQ60GeBBDIPgJ2swcCQpwgTCVhQoL0P0qu2/NQoipGU=";

    # Badged hardcodes /usr/lib/polkit-1/polkit-agent-helper-1 which doesn't
    # exist on NixOS. We point it at our setuid wrapper instead.
    postPatch = ''
      substituteInPlace src/agent.rs \
        --replace-fail '/usr/lib/polkit-1/polkit-agent-helper-1' \
                       '/run/wrappers/bin/polkit-agent-helper-1'
    '';

    nativeBuildInputs = [ pkgs.pkg-config ];
    buildInputs = [ pkgs.gtk4 pkgs.dbus ];

    meta = {
      description = "A polkit authentication agent for Linux window managers";
      homepage = "https://github.com/jfernandez/badged";
      license = pkgs.lib.licenses.mit;
      mainProgram = "badged";
    };
  };
in
{
  security.wrappers.polkit-agent-helper-1 = {
    source = "${pkgs.polkit.out}/lib/polkit-1/polkit-agent-helper-1";
    setuid = true;
    owner = "root";
    group = "root";
  };

  systemd.user.services.polkit-badged = {
    description = "Badged, polkit authentication agent with fingerprint support";
    wants = [ "graphical-session.target" ];
    after = [ "graphical-session.target" ];
    wantedBy = [ "graphical-session.target" ];
    serviceConfig = {
      ExecStart = "${badged}/bin/badged";
      Restart = "on-failure";
      RestartSec = 1;
      TimeoutStopSec = 10;
      Type = "simple";
    };
  };
}
