{ config, pkgs, libs, lib, ... }:
{
  programs.vscode =
  let
      save-and-run = pkgs.vscode-utils.extensionFromVscodeMarketplace {
        name = "save-and-run";
        publisher = "wk-j";
        version = "0.0.22";
        sha256 = "mr6WJ1gmtoBR+wqCfMhtg3OBf3+Mh637j9v416V9A5o=";
      };
      stable_extensions = with pkgs.vscode-extensions; [
        vadimcn.vscode-lldb
        matklad.rust-analyzer
        jnoortheen.nix-ide
        arrterian.nix-env-selector
        bungcip.better-toml
        save-and-run
        asvetliakov.vscode-neovim
      ];
      unstable_extensions = with pkgs.unstable.vscode-extensions; [
        github.copilot
      ];
  in {
      enable = true;
      package = pkgs.vscode-fhs;
      # package = pkgs.vscode.fhsWithPackages (ps: with ps; [ rustup zlib openssl.dev pkg-config ]);
      extensions = stable_extensions ++ unstable_extensions;
      userSettings =
      {
          "extensions.experimental.affinity" = {
            "asvetliakov.vscode-neovim" = 1;
          };
      };
    };
  }

