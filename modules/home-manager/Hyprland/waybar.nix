{pkgs, lib, ...}:
{
    programs.waybar.enable = true;
    programs.waybar.style = ./waybar/style.css;

    xdg.configFile."waybar/config.jsonc".source = ./waybar/config.jsonc;

}
