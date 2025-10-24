{
  config,
  pkgs,
  libs,
  inputs,
  ...
}:
{
  imports = [
    ./home.nix
    #./vim/vim.nix
    ./zsh.nix
    ./cli-linux.nix
    (
      {
        config,
        pkgs,
        inputs,
        ...
      }:
      {
        imports = [
          ./desktop-linux-personal.nix
          ./stylix-common.nix
        ];
        # Pass spicetify-nix to desktop-linux-common.nix
        _module.args = {
          spicetify-nix = inputs.spicetify-nix;
        };
      }
    )
    ./mutt-quickjack.nix
    # ./amateur_radio.nix
    inputs.spicetify-nix.homeManagerModules.spicetify
    # ./theme-personal.nix
    ./hyprland.nix
    ./sway.nix
    ./music-making.nix
  ];

  services.hypridle = {
    enable = true;
    settings = {
      listener = [
        {
          timeout = 180; # 3 minutes
          on-timeout = "hyprctl dispatch dpms off";
          on-resume = "hyprctl dispatch dpms on";
        }
      ];
    };
  };
  programs.ashell = {
    enable = true;
    systemd.enable = true;
  };
}
