{config, pkgs, inputs, lib, ...}:
{
  options = with lib;{
    gui.enable = mkEnableOption "Enable GUI applications";
    games.enable = mkEnableOption "Enable Games on PC";    
    school.enable = mkEnableOption "Enable School Account";

    search = {
      google.enable = mkEnableOption "enable google as a search engine in firefox";
      nix-search.enable = mkEnableOption "enable nix-search as a search engine in firefox";
      cargo.enable = mkEnableOption "enable cargo as a search engine in firefox";
      youtube.enable = mkEnableOption "enable youtube as a search engine in firefox";
      youtube-music.enable = mkEnableOption "enable youtube-music as a search engine in firefox";
    };   
  };
}


