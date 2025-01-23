{config, pkgs, inputs, ...}:
{
  home.packages = with pkgs; [
    google-chrome
    discord
    youtube-music
    obsidian

    rustdesk

  ];
}
