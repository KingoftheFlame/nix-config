{
  pkgs,
  lib,
  ...
}: {
  programs.alacritty = let
    font_family = lib.mkDefault "Maple mono NF";
  in {
    enable = true;
    settings = lib.mkDefault {
      colors = {
        primary = {
          background = "#1a1b26";
          foreground = "#c0caf5";
        };
        normal = {
          black = "#15161e";
          red = "#f7768e";
          green = "#9ece6a";
          yellow = "#e0af68";
          blue = "#7aa2f7";
          magenta = "#bb9af7";
          cyan = "#7dcfff";
          white = "#a9b1d6";
        };
      };
      font = {
        normal = {
          family = font_family;
          style = "Regular";
        };
        bold = {
          family = font_family;
          style = "Bold";
        };
        italic = {
          family = font_family;
          style = "Italic";
        };
        bold_italic = {
          family = font_family;
          style = "Bold Italic";
        };
        size = 12;
      };
    };
  };
}
