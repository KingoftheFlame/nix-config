{config, pkgs, inputs, outputs, lib, ...}:
{
  # options = {
    # gui.enable = lib.mkEnableOption "enable gui applications";
  # };

  config = lib.mkMerge[
    {home.packages = with pkgs; [
      yt-dlp
      ncspot
    ];}

    {home.packages = with pkgs; lib.mkIf config.gui.enable[
      youtube-music
      spotify
      
      yt-dlg
      picard
      # strawberry
      audacious
      lollypop
      # amarok
      sayonara
    ];}
  ];
}

# nix-shell -p  python312Packages.numpy python312Packages.scipy python312Packages.matplotlib

