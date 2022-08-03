{ config, pkgs, libs, lib, ... }:
{
  # Note: Need to add the `v4l2loopback` kernel module in nixos
  home.packages = with pkgs; [
  ]

}
