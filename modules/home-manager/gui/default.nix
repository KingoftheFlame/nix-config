{config, pkgs, inputs, lib, ...}:
{
  # options = {
    # gui.enable = lib.mkEnableOption "";
  # };

  # config = lib.mkIf config.gui.enable{
    home.packages = with pkgs; [
    
      #Productivity
      obsidian
  
      #Media
      # youtube-music
      vlc
  
      google-chrome

      discord

      rustdesk

    ];
  # };
}
