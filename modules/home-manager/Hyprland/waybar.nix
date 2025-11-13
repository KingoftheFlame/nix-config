{pkgs, lib, ...}:
{
    programs.waybar.enable = true;
    programs.waybar.style = ./WaybarTheme/style.css;

    xdg.configFile."waybar/config.jsonc".source = ./WaybarTheme/config.jsonc;

}
