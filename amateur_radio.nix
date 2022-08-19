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

  # services.sdrplayApi.enable = true;
  # nixpkgs.overlays = [
  #   (
  #     self: super:
  #     {
  #       soapysdr-with-plugins = self.soapysdr.override { extraPackages = [ self.soapysdrplay ]; };
  #       sdrpp-with-sdrplay = self.sdrpp.override { sdrplay_source= true; };
  #     }
  #   )
  #   # Zoom screen sharing
  #   (
  #     self: super:
  #     {
  #      zoomUsFixed = pkgs.zoom-us.overrideAttrs (old: {
  #       postFixup = old.postFixup + ''
  #       wrapProgram $out/bin/zoom-us --unset XDG_SESSION_TYPE
  #     '';});
  #        zoom = pkgs.zoom-us.overrideAttrs (old: {
  #     postFixup = old.postFixup + ''
  #       wrapProgram $out/bin/zoom --unset XDG_SESSION_TYPE
  #     '';});
  #     }
  #     )
  # ];

}
