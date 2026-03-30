{ pkgs, inputs, ... }:
{
  home-manager.users.aroman = {
    # import the home manager module
    imports = [
      inputs.noctalia.homeModules.default
    ];

    # Everblush color scheme for noctalia
    xdg.configFile."noctalia/colorschemes/Everblush/Everblush.json".text = builtins.toJSON {
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

    programs.noctalia-shell = {
      enable = true;
    };
  };
}
