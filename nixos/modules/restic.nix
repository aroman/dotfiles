{ config, ... }:

{
  services.restic.backups.b2 = {
    repository = "b2:aroman-backups";
    passwordFile = "/etc/restic/password";
    environmentFile = "/etc/restic/b2-env";
    initialize = true;

    paths = [
      "/home/aroman"
    ];

    exclude = [
      # Caches and trash
      "/home/aroman/.cache"
      "/home/aroman/.local/share/Trash"

      # Nix-managed (reproducible from flake)
      "/home/aroman/.nix-profile"
      "/home/aroman/.nix-defexpr"
      "/home/aroman/.local/state/nix"

      # Flatpak (re-installable)
      "/home/aroman/.local/share/flatpak"
      "/home/aroman/.var"

      # Browser data (large, ephemeral, synced by browser accounts)
      "/home/aroman/.mozilla/firefox/*/storage"
      "/home/aroman/.mozilla/firefox/*/cache2"
      "/home/aroman/.config/google-chrome"
      "/home/aroman/.config/chromium"
      "/home/aroman/.config/Vesktop/sessionData"

      # Downloads (ephemeral)
      "/home/aroman/Downloads"

      # Build artifacts (reproducible)
      "node_modules"
      ".direnv"
      "__pycache__"
      "*.pyc"
      "target"
      "result"

      # Steam (re-downloadable)
      "/home/aroman/.steam"
      "/home/aroman/.local/share/Steam"

      # Containers (re-pullable)
      "/home/aroman/.local/share/containers"
    ];

    timerConfig = {
      OnCalendar = "daily";
      Persistent = true;  # catch up after sleep/shutdown
      RandomizedDelaySec = "1h";
    };

    pruneOpts = [
      "--keep-daily 7"
      "--keep-weekly 4"
      "--keep-monthly 6"
    ];
  };
}
