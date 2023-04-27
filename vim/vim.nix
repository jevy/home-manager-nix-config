{ config, pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [
      vim-airline
      vim-surround
      vim-commentary
      vim-json
      vim-markdown
      base16-vim
      vim-nix
      vim-indent-guides
      vim-gitgutter
      nvim-tree-lua
      fzf-vim
      vim-rooter
      vim-easy-align
      vim-dirdiff
      vim-fugitive
      vim-repeat
      leap-nvim 
      gruvbox-material
    ];

    extraLuaConfig = 
      ''
        require('leap').add_default_mappings()
      '';
  };
}
