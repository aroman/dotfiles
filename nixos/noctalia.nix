{ pkgs, inputs, ... }:
{
  home-manager.users.aroman = {
    # import the home manager module
    imports = [
      inputs.noctalia.homeModules.default
    ];

    # GitHub Dark color scheme for noctalia
    xdg.configFile."noctalia/colorschemes/GitHub Dark/GitHub Dark.json".text = builtins.toJSON {
      dark = {
        mPrimary = "#58a6ff";
        mOnPrimary = "#0d1117";
        mSecondary = "#bc8cff";
        mOnSecondary = "#0d1117";
        mTertiary = "#3fb950";
        mOnTertiary = "#0d1117";
        mError = "#f85149";
        mOnError = "#0d1117";
        mSurface = "#0d1117";
        mOnSurface = "#e6edf3";
        mSurfaceVariant = "#161b22";
        mOnSurfaceVariant = "#8b949e";
        mOutline = "#30363d";
        mShadow = "#010409";
        mHover = "#3fb950";
        mOnHover = "#0d1117";
        terminal = {
          normal = {
            black = "#484f58";
            red = "#f85149";
            green = "#3fb950";
            yellow = "#d29922";
            blue = "#58a6ff";
            magenta = "#bc8cff";
            cyan = "#39d2c0";
            white = "#b1bac4";
          };
          bright = {
            black = "#6e7681";
            red = "#ff7b72";
            green = "#56d364";
            yellow = "#e3b341";
            blue = "#79c0ff";
            magenta = "#d2a8ff";
            cyan = "#56d4cf";
            white = "#f0f6fc";
          };
          foreground = "#e6edf3";
          background = "#0d1117";
          selectionFg = "#e6edf3";
          selectionBg = "#30363d";
          cursorText = "#0d1117";
          cursor = "#e6edf3";
        };
      };
      light = {
        mPrimary = "#0969da";
        mOnPrimary = "#ffffff";
        mSecondary = "#8250df";
        mOnSecondary = "#ffffff";
        mTertiary = "#1a7f37";
        mOnTertiary = "#ffffff";
        mError = "#cf222e";
        mOnError = "#ffffff";
        mSurface = "#ffffff";
        mOnSurface = "#1f2328";
        mSurfaceVariant = "#f6f8fa";
        mOnSurfaceVariant = "#656d76";
        mOutline = "#d0d7de";
        mShadow = "#d1d9e0";
        mHover = "#1a7f37";
        mOnHover = "#ffffff";
        terminal = {
          normal = {
            black = "#24292f";
            red = "#cf222e";
            green = "#1a7f37";
            yellow = "#9a6700";
            blue = "#0969da";
            magenta = "#8250df";
            cyan = "#1b7c83";
            white = "#6e7781";
          };
          bright = {
            black = "#57606a";
            red = "#a40e26";
            green = "#2da44e";
            yellow = "#bf8700";
            blue = "#218bff";
            magenta = "#a475f9";
            cyan = "#3192aa";
            white = "#8c959f";
          };
          foreground = "#1f2328";
          background = "#ffffff";
          selectionFg = "#1f2328";
          selectionBg = "#d0d7de";
          cursorText = "#ffffff";
          cursor = "#1f2328";
        };
      };
    };

    programs.noctalia-shell = {
      enable = true;
    };
  };
}
