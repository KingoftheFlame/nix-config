{pkgs, lib, ...}:
{

    home.packages = with pkgs; [
        kitty
        hyprpolkitagent

        qt5.qtwayland
        qt6.qtwayland
    
        nerd-fonts.ubuntu

        # (nerd-fonts.override { fonts = ["FiraCode" "DroidSansMono" "noto-fonts"];})
        #
        
        adwaita-icon-theme
        papirus-icon-theme
        bibata-cursors
        adwaita-qt
     ];
  

    # Environment variables as a fallback for apps not honoring gsettings
    # Avoid hard overrides so tools like nwg-look can preview/apply themes dynamically.
    home.sessionVariables= {
        GTK2_RC_FILES = "${pkgs.gnome-themes-extra}/share/themes/Adwaita-dark/gtk-2.0/gtkrc"; # GTK2 fallback only
        QT_QPA_PLATFORMTHEME = "gtk3"; # Qt apps follow GTK portal/theme
    };

    # Cursor defaults for XDG/Wayland sessions
    home.sessionVariables = {
        XCURSOR_THEME = "Bibata-Modern-Classic";
        XCURSOR_SIZE = "24";
    };

    fonts.fontconfig.enable = true;
    
}
