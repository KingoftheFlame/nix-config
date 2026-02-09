{pkgs, ...}: {
  home.packages = with pkgs; [
    python3Packages.pip # Python package installer
    python3Packages.virtualenv # Virtual environment tool
    python3Packages.setuptools # Package development library
    python3Packages.black # Code formatter
    python3Packages.flake8 # Linting tool
    python3Packages.mypy # Type checking
    python3Packages.requests # HTTP library for the Weather.py script
  ];

  # Add pip configuration
  home.file.".config/pip/pip.conf".text = ''
    [global]
    user = true
  '';

  # Set environment variables for Python development
  home.sessionVariables = {
    PIP_USER = "1";
  };

  # Create a wrapper script for Weather.py to ensure it uses Python with required packages
  home.file.".local/bin/weather" = {
    text = ''
      #!/bin/sh
      # Use python3 with the correct package path
      exec ${pkgs.python3.withPackages (p: [p.requests])}/bin/python3 $HOME/.config/waybar/scripts/Weather.py "$@"
    '';
    executable = true;
  };

  # Set Python path in environment
  home.sessionPath = ["${pkgs.python3}/bin"];
}
