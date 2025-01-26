{
  config,
  pkgs,
  ...
}: {
  # See the generated vimrc: nixvim-print-init
  programs.nixvim = {
    enable = true;
    colorschemes.gruvbox.enable = true;
    opts = {
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      splitbelow = true;
    };
    vimAlias = true;
    viAlias = true;
    plugins = {
      gitgutter.enable = true;
      lualine.enable = true;
      leap.enable = true;
      lsp = {
        enable = true;
        servers = {
          nil_ls.enable = true; # nix
          ts_ls.enable = true;
          kotlin_language_server.enable = true;
          marksman.enable = true;
        };
      };
      lsp-format.enable = true;
      nvim-tree = {
        enable = true;
        disableNetrw = true;
        hijackNetrw = true;
        onAttach = {
          __raw = ''
            vim.api.nvim_set_keymap("n", "<C-n>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
          '';
        };
      };
      none-ls = {
        enable = true;
        sources = {
          completion = {
            luasnip.enable = true;
          };
          formatting = {
            alejandra.enable = true;
          };
        };
      };
      markview.enable = true;
      rainbow-delimiters.enable = true;
      telescope = {
        enable = true;
        extensions = {
          fzy-native.enable = true;
          fzf-native.enable = true;
        };
        luaConfig.post = ''
          vim.api.nvim_set_keymap("n", "<C-f>", ":Telescope find_files<CR>", { noremap = true, silent = true })
          vim.api.nvim_set_keymap("n", "<C-g>", ":Telescope live_grep<CR>", { noremap = true, silent = true })
        '';
      };
      tmux-navigator.enable = true;
      todo-comments.enable = true;
      trouble.enable = true;
      which-key.enable = true;
      web-devicons.enable = true;
      treesitter = {
        enable = true;
        settings = {
          indent.enable = true;
          highlight.enable = true;
        };

        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          dockerfile
          json
          lua
          kotlin
          make
          markdown
          nix
          javascript
          json
          ruby
          regex
          toml
          vim
          vimdoc
          yaml
        ];
      };
      treesitter-context.enable = true;
      treesitter-textobjects.enable = true;
    };
  };
}
