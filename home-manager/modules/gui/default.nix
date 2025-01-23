{config, pkgs, inputs, ...}:
{
  home.packages = with pkgs; [
    
    #Productivity
    obsidian
  
    #Media
    youtube-music
    vlc
  
    google-chrome

    discord

    rustdesk

  ];
}
