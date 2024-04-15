{ pkgs }:
let
  global-python-packages = with pkgs.python311Packages; [
    # neomutt
    markdown
    wxPython_4_2
    markdown-include
    goobook
  ];
in
pkgs.python311.withPackages (ps: global-python-packages)
