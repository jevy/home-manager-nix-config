{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    soapysdrplay
    gqrx
    cubicsdr
    sdrangel
    hamlib_4
    wsjtx
  ];

}
