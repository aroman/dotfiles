# Granola (granola.ai), which only ships for macOS and Windows, run on Linux.
# Everything Granola lives here and in ./granola/; importing this module is
# the whole integration, and dropping the import removes all of it.
#
#   granola/package.nix       macOS bundle on nixpkgs' Electron (bump notes inside)
#   granola/patch_app.py      the Linux patches to Granola's JS
#   granola/niri.kdl          autostart, popup and screen-share window rules
#   granola/noctalia-plugin/  bar widget for the next meeting
{ lib, username, ... }:
{
  # As pkgs.granola, so `nix build .#nixosConfigurations.<host>.pkgs.granola`
  # builds exactly what the host installs (with its allowUnfree).
  nixpkgs.overlays = [
    (final: _: { granola = final.callPackage ./granola/package.nix { }; })
  ];

  home-manager.users.${username} = { config, pkgs, ... }:
    let
      link = path: config.lib.file.mkOutOfStoreSymlink
        "${config.home.homeDirectory}/Projects/dotfiles/nixos/granola/${path}";
    in
    {
      home.packages = [ pkgs.granola ];

      # Sign-in hands the token back via granola://.
      xdg.mimeApps.defaultApplications."x-scheme-handler/granola" = "granola.desktop";

      # config/niri/config.kdl includes this path with optional=true, so hosts
      # without this module simply skip it.
      xdg.configFile."niri-nix/granola.kdl".source = link "niri.kdl";

      # Next meeting in the bar. Granola writes what its macOS menu-bar item
      # would show to $XDG_RUNTIME_DIR/granola/next-meeting.json (patch_app.py);
      # the widget hides when Granola isn't running or nothing is coming up.
      # Linked to the repo like the rcm-delivered plugins, so edits hot-reload.
      xdg.dataFile."noctalia/plugins/granola".source = link "noctalia-plugin";
      programs.noctalia.settings = {
        plugins.enabled = [ "aroman/granola" ];
        widget.granola.type = "aroman/granola:next-meeting";
        bar.main.end = lib.mkBefore [ "granola" ];
      };
    };
}
