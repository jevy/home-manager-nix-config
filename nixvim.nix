{
  config,
  pkgs,
  ...
}: {
  # See the generated vimrc: nixvim-print-init
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    extraPlugins = [
      pkgs.vimPlugins.leap-nvim
      pkgs.vimPlugins.vim-rooter
    ];
    extraConfigLua =
      # lua
      ''
        require("leap").set_default_mappings()
      '';
    extraConfigVim = ''
      " vim-rooter configuration
      let g:rooter_patterns = ['.git', 'Makefile', 'package.json', 'flake.nix', 'Cargo.toml', 'pyproject.toml', 'go.mod']
      let g:rooter_change_directory_for_non_project_files = 'current'
      let g:rooter_silent_chdir = 0
      let g:rooter_resolve_links = 1
    '';
    # Using stylix nixvim module instead
    # colorschemes.gruvbox.enable = true;
    opts = {
      relativenumber = true;
      expandtab = true;
      shiftwidth = 2;
      tabstop = 2;
      splitbelow = true;
      showmatch = true;
      ignorecase = true;
      scrolloff = 5;
      incsearch = true;
      writebackup = false;
      backup = false;
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
          # ts_ls.enable = true;
          kotlin_language_server.enable = true;
          marksman.enable = true;
          gopls.enable = true;
        };
      };
      lsp-format.enable = true;
      nvim-tree = {
        enable = true;
        settings = {
          disable_netrw = true;
          hijack_netrw = true;
          filters = {
            dotfiles = true;
          };
          on_attach = {
            __raw = ''
              vim.api.nvim_set_keymap("n", "<C-n>", ":NvimTreeToggle<CR>", { noremap = true, silent = true })
            '';
          };
          update_focused_file = {
            enable = true;
          };
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
      markview.enable = false;
      rainbow-delimiters.enable = false;
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
      todo-comments.enable = true;
      trouble.enable = true;
      which-key.enable = true;
      web-devicons.enable = true;
      treesitter = {
        enable = true;
        settings = {
          indent.enable = true;
          highlight.enable = true;
          incremental_selection = {
            enable = true;
            keymaps = {
              init_selection = false;
              node_decremental = "grl"; # less
              node_incremental = "grm"; # more
              scope_incremental = "grc";
            };
          };
        };
        grammarPackages = with pkgs.vimPlugins.nvim-treesitter.builtGrammars; [
          bash
          csv
          dockerfile
          json
          lua
          kotlin
          make
          markdown
          nix
          gitcommit
          gitignore
          javascript
          json
          ruby
          regex
          toml
          typescript
          tsx
          vim
          vimdoc
          yaml
        ];
      };
      treesitter-context.enable = true;
      treesitter-textobjects = {
        enable = true;
        settings = {
          select = {
            enable = true;
            lookahead = false;
            keymaps = {
              "af" = "@function.outer";
              "if" = "@function.inner";
              "il" = "@loop.inner";
              "al" = "@loop.outer";
              "icd" = "@conditional.inner";
              "acd" = "@conditional.outer";
              "acm" = "@comment.outer";
              "ast" = "@statement.outer";
              "isc" = "@scopename.inner";
              "iB" = "@block.inner"; # Mini uses this for brackets
              "aB" = "@block.outer";
              "ia" = "@parameter.inner";
              "aa" = "@parameter.outer";
            };
          };
          move = {
            enable = true;
            set_jumps = true;
            goto_next_start = {
              "]m" = "@function.outer";
              "]im" = "@function.inner";
              "]c" = "@call.outer";
              "]ic" = "@call.inner";
            };
            goto_next_end = {
              "]M" = "@function.outer";
              "]iM" = "@function.inner";
              "g)" = "@parameter.inner";
              "]C" = "@call.outer";
              "]iC" = "@call.inner";
            };
            goto_previous_start = {
              "[m" = "@function.outer";
              "[im" = "@function.inner";
              "[c" = "@call.outer";
              "[ic" = "@call.inner";
            };
            goto_previous_end = {
              "[M" = "@function.outer";
              "[iM" = "@function.inner";
              "g(" = "@parameter.inner";
              "[C" = "@call.outer";
              "[iC" = "@call.inner";
            };
          };
          lsp_interop = {
            enable = true;
            border = "none";
            floating_preview_opts = {};
            peek_definition_code = {
              "<leader>df" = "@function.outer";
              "<leader>dF" = "@class.outer";
            };
          };
        };
      };
    };
  };
}
