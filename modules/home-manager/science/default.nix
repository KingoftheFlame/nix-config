{config, pkgs, inputs, ...}:
{
  home.packages = with pkgs; [
   numbat
   jupyter   

   python312Packages.matplotlib
   python312Packages.numpy 
   python312Packages.scipy   
   #spyder
   octave
   #kicad
  ];
}

# nix-shell -p  python312Packages.numpy python312Packages.scipy python312Packages.matplotlib

