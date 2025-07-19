{pkgs, config, ...}:
{
  home.packages = with pkgs;[
    # arduino
    # arduino-cli
    arduino-ide
    rpi-imager
    kicad
    
    gtk2
    kdePackages.ghostwriter
    podman
    podman-compose


    #c++
    gcc
    gdb
  
  ];
}
  

