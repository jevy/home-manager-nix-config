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
      vim-easy-align

      # Tree Sitter stuff
      (nvim-treesitter.withPlugins (
        plugins: with pkgs.tree-sitter-grammars; [
          tree-sitter-ruby
          tree-sitter-nix
          tree-sitter-regex
          tree-sitter-yaml
          tree-sitter-vim
          tree-sitter-json
          tree-sitter-markdown
          tree-sitter-dockerfile
          tree-sitter-lua

        ]
      ))
      # completion-treesitter
      nvim-treesitter-textobjects
      nvim-treesitter-context
      vim-lsp


      plenary-nvim
      telescope-nvim
      telescope-fzy-native-nvim

    ];
    extraPackages = with pkgs; [
      # Ruby LSP - https://blog.backtick.consulting/neovims-built-in-lsp-with-ruby-and-rails/
      rubyPackages.solargraph
      # rubocop
      # tree-sitter
    ];
    extraConfig = builtins.concatStringsSep "\n" [
        (lib.strings.fileContents ./base.vim)
      ''
        lua << EOF
        require("nvim-tree").setup()
        vim.api.nvim_set_keymap('n', '<C-n>', ':NvimTreeToggle<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('n', '<C-f>', ':Telescope find_files<CR>', { noremap = true, silent = true })
        vim.api.nvim_set_keymap('n', '<C-g>', ':Telescope live_grep<CR>', { noremap = true, silent = true })

        require("nvim-treesitter.configs").setup {
          highlight = {
            enable = true,
          },
          indent = {
            enable = true,
          }
        }
        EOF
      ''
      ];
  };
}
