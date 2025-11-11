{pkgs, lib, ...}:
{

    home.packages = with pkgs; [
        kitty
        hyprpolkitagent

        qt5.qtwayland
        qt6.qtwayland
    
        nerd-fonts.ubuntu
        # (nerd-fonts.override { fonts = ["FiraCode" "DroidSansMono" "noto-fonts"];})
    ];

    wayland.windowManager.hyprland.enable = true;

    wayland.windowManager.hyprland.settings = {        
        "$mainMod" = "mod4";
        bind = ["$mainMod, q, exec, kitty"];
        
       exec-once = [
        "[workspace 1 silent] kitty"
        "[workspace 2 silent] firefox-devedition"
        "systemctl --user start hyprpolkitagent"
        
       ]; 
    };

    fonts.fontconfig.enable = true;
    
}
