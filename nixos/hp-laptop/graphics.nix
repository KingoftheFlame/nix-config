{ ... }:
{
  programs.hyprland = {
    enable = true;
    xwayland.enable = true;
  };

  hardware = {
    #Opengl
    opengl.enable = true;
  };
}
