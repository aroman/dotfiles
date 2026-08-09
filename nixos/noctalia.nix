# Noctalia v5 (native C++ rewrite; v4 was QML on Quickshell).
#
# v5 splits config into two layers, which is why this file can be fully
# declarative where v4 could not:
#
#   ~/.config/noctalia/*.toml          read-only, generated here, merged
#                                      alphabetically
#   ~/.local/state/noctalia/settings.toml   the ONLY file the GUI writes,
#                                      and it wins over anything below it
#
# v4 rewrote its own settings.json in place (noctalia-shell#2214), which is why
# modules/home.nix used to copy config into a writable runtime dir instead of
# symlinking it.  That whole activation dance is gone — the state layer is now
# upstream's answer to exactly that problem.
#
# Consequence worth knowing: GUI changes still shadow everything here, they're
# just contained in one file.  To see what's drifted, run `noctalia-dump`; to
# reset, delete ~/.local/state/noctalia/settings.toml.
{ config, inputs, pkgs, ... }:
{
  home-manager.users.aroman = {
    imports = [ inputs.noctalia.homeModules.default ];

    programs.noctalia = {
      enable = true;

      # Prebuilt from cache.nixos.org.  The noctalia flake input's own package
      # output is a from-source C++ build against our nixpkgs, which nothing
      # has cached; nixpkgs' by-name package is the same version and is on the
      # binary cache.  Keep it pinned to the same tag as the flake input.
      package = pkgs.noctalia;

      # v4 called these colorschemes and kept them under colorschemes/<name>/<name>.json;
      # v5 calls them palettes at palettes/<name>.json.  The JSON payload is
      # byte-for-byte the same format, so this carried over unchanged.
      customPalettes.Everblush = {
        dark = {
          mPrimary = "#67b0e8";
          mOnPrimary = "#141b1e";
          mSecondary = "#c47fd5";
          mOnSecondary = "#141b1e";
          mTertiary = "#8ccf7e";
          mOnTertiary = "#141b1e";
          mError = "#e57474";
          mOnError = "#141b1e";
          mSurface = "#141b1e";
          mOnSurface = "#dadada";
          mSurfaceVariant = "#1e2528";
          mOnSurfaceVariant = "#b3b9b8";
          mOutline = "#232a2d";
          mShadow = "#0b1012";
          mHover = "#8ccf7e";
          mOnHover = "#141b1e";
          terminal = {
            normal = {
              black = "#232a2d";
              red = "#e57474";
              green = "#8ccf7e";
              yellow = "#e5c76b";
              blue = "#67b0e8";
              magenta = "#c47fd5";
              cyan = "#6cbfbf";
              white = "#b3b9b8";
            };
            bright = {
              black = "#2d3437";
              red = "#ef7e7e";
              green = "#96d988";
              yellow = "#f4d67a";
              blue = "#71baf2";
              magenta = "#ce89df";
              cyan = "#67cbe7";
              white = "#bdc3c2";
            };
            foreground = "#dadada";
            background = "#141b1e";
            selectionFg = "#dadada";
            selectionBg = "#2d3437";
            cursorText = "#141b1e";
            cursor = "#dadada";
          };
        };
        light = {
          mPrimary = "#4889b2";
          mOnPrimary = "#ffffff";
          mSecondary = "#9b5aab";
          mOnSecondary = "#ffffff";
          mTertiary = "#5a9e50";
          mOnTertiary = "#ffffff";
          mError = "#c24b4b";
          mOnError = "#ffffff";
          mSurface = "#f5f5f5";
          mOnSurface = "#1a2225";
          mSurfaceVariant = "#e8ecee";
          mOnSurfaceVariant = "#5a6568";
          mOutline = "#c8cfd2";
          mShadow = "#b8bfc2";
          mHover = "#5a9e50";
          mOnHover = "#ffffff";
          terminal = {
            normal = {
              black = "#232a2d";
              red = "#c24b4b";
              green = "#5a9e50";
              yellow = "#b89a3e";
              blue = "#4889b2";
              magenta = "#9b5aab";
              cyan = "#4a9696";
              white = "#6e7776";
            };
            bright = {
              black = "#3d4648";
              red = "#e57474";
              green = "#8ccf7e";
              yellow = "#e5c76b";
              blue = "#67b0e8";
              magenta = "#c47fd5";
              cyan = "#6cbfbf";
              white = "#8a908f";
            };
            foreground = "#1a2225";
            background = "#f5f5f5";
            selectionFg = "#1a2225";
            selectionBg = "#c8cfd2";
            cursorText = "#f5f5f5";
            cursor = "#1a2225";
          };
        };
      };

      # Rendered to ~/.config/noctalia/config.toml and checked at build time by
      # `noctalia config validate` (programs.noctalia.validateConfig, on by
      # default) — a typo here fails the rebuild instead of the session.
      settings = {
        accessibility.ui_scale = 1.15;

        shell = {
          font_family = "Inter";
          # Replaces nixos/badged.nix: v5 has a native polkit agent that drives
          # the fprintd PAM conversation.  Verified working 2026-08-01.
          polkit_agent = true;
          settings_show_advanced = false;
          animation.speed = 1.15;
          panel.open_near_click_control_center = true;
        };

        theme = {
          mode = "dark";
          source = "custom";
          custom_palette = "Everblush";
        };

        bar.main = {
          position = "top";
          background_opacity = 0.49;
          margin_edge = 8;
          margin_ends = 8;
          widget_spacing = 8;
          layer = "overlay";
          shadow = false;

          # All four v4 plugins are gone and none needed porting to Luau:
          #   hostname          -> built-in "text" widget, below
          #   privacy-indicator -> built-in "privacy" widget (not placed; it
          #                        wasn't in the v4 bar either)
          #   voxtype           -> dropped; voxtype has its own native indicator
          #   cloudflare-tunnel -> dropped; not run from this machine, and
          #                        there's a terminal alias for it anyway
          start = [ "hostname" "spacer" "media" ];
          center = [ "active-window" ];
          end = [
            "tray"
            "sysmon"
            "volume"
            "network"
            "bluetooth"
            "refresh-toggle"
            "battery"
            "notifications"
            "clock"
          ];
        };

        # v4 shipped a 57-line QML plugin whose entire job was shelling out to
        # `hostname`.  Nix already knows the hostname at build time, so a
        # built-in text widget replaces the plugin outright — and stays correct
        # across hosts because this module is shared by all of them.
        widget.hostname = {
          type = "text";
          text = config.networking.hostName;
        };

        # v4 CustomButton.  Note the label is static: v4 re-ran
        # `refresh-toggle status` every 30s to show the current rate, and v5's
        # custom_button has no command-polling equivalent (the text widget is
        # fixed-string only).  Recovering the live readout means a Luau plugin.
        widget.refresh-toggle = {
          type = "custom_button";
          glyph = "device-desktop";
          tooltip = "Toggle refresh rate (165/60 Hz)";
          actions.left = "exec /home/aroman/.local/bin/refresh-toggle";
        };

        dock.launcher_position = "start";
        desktop_widgets.enabled = false;

        wallpaper = {
          transition = [ "zoom" ];
          transition_on_startup = true;
          default.path = "/home/aroman/Pictures/Wallpapers/wallpaper.png";
          monitors.eDP-1.path = "/home/aroman/Pictures/Wallpapers/wallpaper.png";
        };

        lockscreen_widgets = {
          enabled = false;
          schema_version = 2;
          widget_order = [ "lockscreen-login-box@eDP-1" ];
          grid = {
            cell_size = 16;
            major_interval = 4;
            visible = true;
          };
          widget."lockscreen-login-box@eDP-1" = {
            type = "login_box";
            output = "eDP-1";
            box_width = 810.0;
            box_height = 196.0;
            cx = 854.0;
            cy = 885.0;
            rotation = 0.0;
            settings = {
              layout = "regular";
              background_color = "surface_variant";
              background_opacity = 0.88;
              background_radius = 12.0;
              input_opacity = 1.0;
              input_radius = 6.0;
              center_password_text = false;
              show_caps_lock = true;
              show_keyboard_layout = true;
              show_login_button = true;
              show_media = true;
              show_session_buttons = true;
              show_unlock_hint = true;
              show_weather = true;
            };
          };
        };
      };
    };
  };
}
