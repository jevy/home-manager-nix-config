{ config, pkgs, libs, ... }:
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
      goyo-vim
      # ranger-vim
      base16-vim
      vim-nix
      gruvbox
      vim-indent-guides
      vim-gitgutter
      nvim-tree-lua
      nvim-web-devicons # for nvim-tree
      fzf-vim
      vim-sneak
      vim-rooter

      # Tree Sitter stuff
      (nvim-treesitter.withPlugins (
        plugins: with plugins; [
          tree-sitter-ruby
          tree-sitter-nix
          tree-sitter-regex
          tree-sitter-yaml
        ]
      ))
      # completion-treesitter
      # nvim-treesitter-textobjects
      # nvim-treesitter-context

    ];
    extraConfig = builtins.concatStringsSep "\n" [
        (lib.strings.fileContents ./base.vim)
      ];
  };
  home.packages = with pkgs; [
    # Ruby LSP - https://blog.backtick.consulting/neovims-built-in-lsp-with-ruby-and-rails/
    solargraph
    rubocop
  ];
}
