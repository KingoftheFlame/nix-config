{pkgs, config, ...}:
{
  home.packages = with pkgs;[
    # arduino
    # arduino-cli
    arduino-ide
    rpi-imager
    gtk2
    kdePackages.ghostwriter
    podman
    podman-compose


    #c++
    gcc
    gdb
  
  ];
}
  

