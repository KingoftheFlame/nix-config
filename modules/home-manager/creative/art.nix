{pkgs, config,...}:
{
  home.packages = with pkgs;[
    krita
    gimp
    blender
    
  ];
}
