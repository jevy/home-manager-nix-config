{ config, pkgs, libs, ... }:
{
  home.packages = with pkgs; [
    soapysdrplay
    soapysdr-with-plugins
    gqrx
    # cubicsdr #segfaults
    sdrangel
    hamlib_4
    wsjtx
    sdrpp
  ];

}
