{pkgs, lib, ...}:
{
    imports =
    [
        ./theme.nix
        ./waybar.nix
    ];

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
        bind = [
            #open terminal
            "$mainMod, q, exec, kitty"
        ];
        
       exec-once = [
        "waybar"
        "systemctl --user start hyprpolkitagent"
       ]; 
    };

    fonts.fontconfig.enable = true;
    
}
