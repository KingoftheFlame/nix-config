{config, pkgs, outputs, inputs, lib, ...}:
{
  # options = {
    # gui.enable = lib.mkEnableOption "";
  # };

  # config = lib.mkIf config.gui.enable{
    home.packages = with pkgs; [
    
  
      google-chrome

      # rustdesk

    ];
  # };
}
