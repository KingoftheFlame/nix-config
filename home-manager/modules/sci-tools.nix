{config, pkgs, inputs, ...}:
{
  home.packages = with pkgs; [
   numbat
   jupyter   
   #python312Full
   #spyder
   octave
   #kicad
  ];
}
