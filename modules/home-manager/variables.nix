{
  # Git Configuration ( For Pulling Software Repos )
  gitUsername = "Don Williams";
  gitEmail = "don.e.williams@gmail.com";

  # Set Displau Manager
  # `tui` for Text login
  # `sddm` for graphical GUI
  # SDDM background is set with stylixImage
  displayManager = "sddm";

  # Emable/disable bundled applications
  tmuxEnable = true;
  alacrittyEnable = true;
  weztermEnable = true;
  ghosttyEnable = true;
  vscodeEnable = true;
  antigravityEnable = false; # Google port of vscodium
  helixEnable = true;
  #To install rebuild, then run zcli doom install
  doomEmacsEnable = false;

  # Python development tools
  pythonEnable = false;

  # P10K or starship prompt
  userPrompt = "starship";

  # Hyprland Settings
  extraMonitorSettings = "monitor=Virtual-1,1920x1080@75,auto,1";

  # Bar/Shell Settings
  # Choose between noctalia or waybar
  barChoice = "noctalia";

  # Waybar Settings (used when barChoice = "waybar")
  clock24h = false;

  # Program Options
  browser = "brave"; # Set Default Browser (google-chrome-stable for google-chrome)

  # Host-level default applications (picked up by Home Manager xdg.mimeApps)
  # Uncomment and adjust the .desktop IDs to set per-host defaults.
  # mimeDefaultApps = {
  #   # PDFs
  #   "application/pdf" = ["okular.desktop"];
  #   "application/x-pdf" = ["okular.desktop"];
  #   # Web browser
  #   "x-scheme-handler/http"  = ["google-chrome.desktop"];  # or brave-browser.desktop, firefox.desktop
  #   "x-scheme-handler/https" = ["google-chrome.desktop"];
  #   "text/html"              = ["google-chrome.desktop"];
  #   # Files
  #   "inode/directory" = ["thunar.desktop"];      # file manager
  #   "text/plain"      = ["nvim.desktop"];        # or code.desktop
  # };

  terminal = "kitty"; # Set Default System Terminal
  keyboardLayout = "us";
  keyboardVariant = "";
  consoleKeyMap = "us";

  # For hybrid support (Intel/NVIDIA Prime or AMD/NVIDIA)
  intelID = "PCI:1:0:0";
  amdgpuID = "PCI:5:0:0";
  nvidiaID = "PCI:0:2:0";

  # Enable NFS
  enableNFS = true;

  # Enable Printing Support
  printEnable = false;

  # Enable Thunar GUI File Manager
  thunarEnable = true;

  # Set Stylix Image
  # This will set your color palette
  # Default background
  # Add new images to ~/zaneyos/wallpapers
  stylixImage = ../../wallpapers/mountainscapedark.jpg;
  #stylixImage = ../../wallpapers/AnimeGirlNightSky.jpg;
  #stylixImage = ../../wallpapers/Anime-Purple-eyes.png;
  #stylixImage = ../../wallpapers/Rainnight.jpg;
  #stylixImage = ../../wallpapers/zaney-wallpaper.jpg;
  #stylixImage = ../../wallpapers/nix-wallpapers-strips-logo.jpg;
  #stylixImage = ../../wallpapers/beautifulmountainscape.jpg;

  # Set Waybar
  # Available options:
  waybarChoice = ../../modules/home/waybar/waybar-dwm-2.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-simple.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-curved.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jerry.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-ddubs.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-ddubs-2.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-dwm.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-TheBlackDon.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-tony.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-ddubsos-v1.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-mecha.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jak-catppuccin.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jak-ml4w-modern.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jak-oglo-simple.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jwt-catppuccin.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jwt-transparent.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-jwt-ultradark.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-pctrade-catppuccin.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-mangowc-jak-catppuccin.nix;
  #waybarChoice = ../../modules/home/waybar/waybar-old-ddubsos.nix;

  # Set Animation style
  # Available options are:
  animChoice = ../../modules/home/hyprland/animations-end4.nix;
  #animChoice = ../../modules/home/hyprland/animations-def.nix;
  #animChoice = ../../modules/home/hyprland/animations-end4-slide.nix;
  #animChoice = ../../modules/home/hyprland/animations-end-slide.nix;
  #animChoice = ../../modules/home/hyprland/animations-dynamic.nix;
  #animChoice = ../../modules/home/hyprland/animations-moving.nix;
  #animChoice = ../../modules/home/hyprland/animations-hyde-optimized.nix;
  #animChoice = ../../modules/home/hyprland/animations-mahaveer-me-1.nix;
  #animChoice = ../../modules/home/hyprland/animations-mahaveer-me-2.nix;
  #animChoice = ../../modules/home/hyprland/animations-ml4w-classic.nix;
  #animChoice = ../../modules/home/hyprland/animations-ml4w-fast.nix;
  #animChoice = ../../modules/home/hyprland/animations-ml4w-high.nix;

  # Set network hostId if required (needed for zfs)
  # Otherwise leave as-is
  hostId = "5ab03f50";
}
