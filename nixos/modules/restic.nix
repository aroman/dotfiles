{ config, pkgs, username, resticRepository, ... }:

# Secrets required on each machine (not tracked in repo):
#   /etc/restic/password         — restic repo encryption password (same on all machines)
#   /etc/restic/b2-env           — B2_ACCOUNT_ID and B2_ACCOUNT_KEY (per-machine key)
#   /etc/restic/healthchecks-url — Healthchecks.io ping URL (per-machine check)

let
  homeDirectory = "/home/${username}";
in
{
  environment.systemPackages = [ pkgs.restic ];

  services.restic.backups.b2 = {
    repository = resticRepository;
    passwordFile = "/etc/restic/password";
    environmentFile = "/etc/restic/b2-env";
    initialize = true;

    paths = [
      homeDirectory
    ];

    exclude = [
      # Caches and trash
      "${homeDirectory}/.cache"
      "${homeDirectory}/.local/share/Trash"

      # Nix-managed (reproducible from flake)
      "${homeDirectory}/.nix-profile"
      "${homeDirectory}/.nix-defexpr"
      "${homeDirectory}/.local/state/nix"

      # Flatpak (re-installable)
      "${homeDirectory}/.local/share/flatpak"
      "${homeDirectory}/.var"

      # Browser data (large, ephemeral, synced by browser accounts)
      "${homeDirectory}/.mozilla/firefox/*/storage"
      "${homeDirectory}/.mozilla/firefox/*/cache2"
      "${homeDirectory}/.config/google-chrome"
      "${homeDirectory}/.config/chromium"
      "${homeDirectory}/.config/discord"

      # Downloads (ephemeral)
      "${homeDirectory}/Downloads"

      # Build artifacts (reproducible)
      "node_modules"
      ".direnv"
      "__pycache__"
      "*.pyc"
      "target"
      "result"

      # Steam (re-downloadable)
      "${homeDirectory}/.steam"
      "${homeDirectory}/.local/share/Steam"

      # Containers (re-pullable)
      "${homeDirectory}/.local/share/containers"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # catch up after sleep/shutdown
      RandomizedDelaySec = "1h";
    };

    extraBackupArgs = [ "--verbose" ];

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];

    # Ping Healthchecks.io on success (URL stored per-machine in /etc/restic/healthchecks-url)
    backupCleanupCommand = ''
      ${pkgs.curl}/bin/curl -fsS -m 10 --retry 5 "$(cat /etc/restic/healthchecks-url)"
    '';
  };
}
