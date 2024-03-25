{ pkgs }:

let
  # Define all Python packages needed globally here
  global-python-packages = python-packages: with python-packages; [

    # For Vim ranger
    pynvim
    ueberzug

    # For neomutt
    markdown
    wxPython_4_2
    markdown-include
  ];

  # Create a Python environment with the defined packages
  python-with-global-packages = pkgs.python311.withPackages global-python-packages;

in
python-with-global-packages
