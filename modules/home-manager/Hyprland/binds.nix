{pkgs, lib, ...}:
{
    wayland.windowManager.hyprland.settings = {        
        "$mainMod" = "mod4";
        bind = [
            #open terminal
            "$mainMod, q, exec, kitty"
            
            #close Hyprland
            "$mainMod, m, exec, hyprctl dispatch exit"

            #program launcher
            "$mainMod, r, exec,rofi"

            #enable special function keys
            ",XF86AudioRaiseVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"
            ",XF86AudioLowerVolume,exec,wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"
            ",XF86AudioMute, exec, wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"
            ",XF86AudioPlay, exec, playerctl play-pause"
            ",XF86AudioPause, exec, playerctl play-pause"
            ",XF86AudioNext, exec, playerctl next"
            ",XF86AudioPrev, exec, playerctl previous"
            ",XF86MonBrightnessDown,exec,brightnessctl set 5%-"
            ",XF86MonBrightnessUp,exec,brightnessctl set +5%"

        ];

        bindm = [
            "$modifier, mouse:272, movewindow"
            "$modifier, mouse:273, resizewindow"
        ];


    };
}