{ config, pkgs, lib, ... }:
{
  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    defaultEditor = true;
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
      gruvbox-material
      vim-indent-guides
      vim-gitgutter
      nvim-tree-lua
      nvim-web-devicons # for nvim-tree
      fzf-vim
      vim-rooter
      vim-easy-align
      vim-dirdiff
      vim-fugitive

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
      nvim-lspconfig

      plenary-nvim
      telescope-nvim
      telescope-fzy-native-nvim
    ]
    ++ [pkgs.unstable.vimPlugins.leap-nvim];

    extraPackages = with pkgs; [
      # Ruby LSP - https://blog.backtick.consulting/neovims-built-in-lsp-with-ruby-and-rails/
      rubyPackages.solargraph
      rnix-lsp
      ltex-ls
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

        require('leap').add_default_mappings()

        require'lspconfig'.ltex.setup{}
        require'lspconfig'.rnix.setup{}
        require'lspconfig'.solargraph.setup{}
        EOF
      ''
      ];
  };
}
