{
  config,
  pkgs,
  ...
}:
{
  # See the generated vimrc: nixvim-print-init
  programs.nixvim = {
    enable = true;
    defaultEditor = true;
    # Symlink ecma/jsx query files needed for tsx/typescript treesitter inheritance
    extraFiles = {
      "queries/ecma".source = "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries/ecma";
      "queries/jsx".source = "${pkgs.vimPlugins.nvim-treesitter}/runtime/queries/jsx";
    };
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
    keymaps = [
      # Flash: jump
      { mode = ["n" "x" "o"]; key = "s"; action.__raw = "function() require('flash').jump() end"; options = { silent = true; desc = "Flash"; }; }
      # Flash: treesitter selection (use ; and , or <C-space>/<BS> to grow/shrink)
      { mode = ["n" "x" "o"]; key = "S"; action.__raw = "function() require('flash').treesitter() end"; options = { silent = true; desc = "Flash Treesitter"; }; }
      # Flash: remote (operator pending)
      { mode = "o"; key = "r"; action.__raw = "function() require('flash').remote() end"; options = { silent = true; desc = "Remote Flash"; }; }
      # Flash: treesitter search
      { mode = ["o" "x"]; key = "R"; action.__raw = "function() require('flash').treesitter_search() end"; options = { silent = true; desc = "Treesitter Search"; }; }
      # Flash: toggle in search mode
      { mode = "c"; key = "<C-s>"; action.__raw = "function() require('flash').toggle() end"; options = { silent = true; desc = "Toggle Flash Search"; }; }
      # Treesitter incremental selection with grow/shrink
      { mode = ["n" "x" "o"]; key = "<C-space>"; action.__raw = ''
        function()
          require('flash').treesitter({
            actions = {
              ["<C-space>"] = "next",
              ["<BS>"] = "prev"
            }
          })
        end
      ''; options = { silent = true; desc = "Treesitter incremental selection"; }; }
    ];
    plugins = {
      gitgutter.enable = true;
      lualine.enable = true;
      flash = {
        enable = true;
        settings = {
          # Show labels after just 1 character (like leap/sneak)
          label.min_pattern_length = 1;
          # Jump after 2 chars if unique match (sneak-style)
          jump.autojump = true;
          modes = {
            char = {
              jump_labels = true;
            };
          };
        };
      };
      project-nvim = {
        enable = true;
        autoLoad = true;
      };
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
      mini = {
        enable = true;
        modules = {
          ai = {
            n_lines = 500;
            search_method = "cover_or_next";
          };
          bracketed = {};  # ]a/[a for arguments, ]f/[f for functions, etc.
        };
      };
      luasnip.enable = true;
      friendly-snippets.enable = true;
      cmp-nvim-lsp.enable = true;
      cmp-buffer.enable = true;
      cmp-path.enable = true;
      cmp-luasnip.enable = true;
      cmp = {
        enable = true;
        autoEnableSources = true;
        settings = {
          sources = [
            { name = "nvim_lsp"; }
            { name = "luasnip"; }
            { name = "buffer"; }
            { name = "path"; }
          ];
          mapping = {
            "<C-Space>" = "cmp.mapping.complete()";
            "<C-e>" = "cmp.mapping.abort()";
            "<CR>" = "cmp.mapping.confirm({ select = true })";
            "<Tab>" = ''
              cmp.mapping(function(fallback)
                local luasnip = require('luasnip')
                if cmp.visible() then
                  cmp.select_next_item()
                elseif luasnip.expand_or_jumpable() then
                  luasnip.expand_or_jump()
                else
                  fallback()
                end
              end, { 'i', 's' })
            '';
            "<S-Tab>" = ''
              cmp.mapping(function(fallback)
                local luasnip = require('luasnip')
                if cmp.visible() then
                  cmp.select_prev_item()
                elseif luasnip.jumpable(-1) then
                  luasnip.jump(-1)
                else
                  fallback()
                end
              end, { 'i', 's' })
            '';
          };
        };
      };
      treesitter = {
        enable = true;
        highlight.enable = true;
        indent.enable = true;
        # Using default allGrammars - remove this comment and add grammarPackages back if you want to limit parsers
      };
      treesitter-context.enable = true;
      # treesitter-textobjects = {
      #   enable = true;
      #   settings = {
      #     select = {
      #       enable = true;
      #       lookahead = false;
      #       keymaps = {
      #         "af" = "@function.outer";
      #         "if" = "@function.inner";
      #         "il" = "@loop.inner";
      #         "al" = "@loop.outer";
      #         "icd" = "@conditional.inner";
      #         "acd" = "@conditional.outer";
      #         "acm" = "@comment.outer";
      #         "ast" = "@statement.outer";
      #         "isc" = "@scopename.inner";
      #         "iB" = "@block.inner"; # Mini uses this for brackets
      #         "aB" = "@block.outer";
      #         "ia" = "@parameter.inner";
      #         "aa" = "@parameter.outer";
      #       };
      #     };
      #     move = {
      #       enable = true;
      #       set_jumps = true;
      #       goto_next_start = {
      #         "]m" = "@function.outer";
      #         "]im" = "@function.inner";
      #         "]c" = "@call.outer";
      #         "]ic" = "@call.inner";
      #       };
      #       goto_next_end = {
      #         "]M" = "@function.outer";
      #         "]iM" = "@function.inner";
      #         "g)" = "@parameter.inner";
      #         "]C" = "@call.outer";
      #         "]iC" = "@call.inner";
      #       };
      #       goto_previous_start = {
      #         "[m" = "@function.outer";
      #         "[im" = "@function.inner";
      #         "[c" = "@call.outer";
      #         "[ic" = "@call.inner";
      #       };
      #       goto_previous_end = {
      #         "[M" = "@function.outer";
      #         "[iM" = "@function.inner";
      #         "g(" = "@parameter.inner";
      #         "[C" = "@call.outer";
      #         "[iC" = "@call.inner";
      #       };
      #     };
      #     lsp_interop = {
      #       enable = true;
      #       border = "none";
      #       floating_preview_opts = { };
      #       peek_definition_code = {
      #         "<leader>df" = "@function.outer";
      #         "<leader>dF" = "@class.outer";
      #       };
      #     };
      #   };
      # };
    };
    extraConfigLua = ''
      -- Option 1: Use Java parser for Kotlin (better indent, but highlighting may be off)
      -- vim.treesitter.language.register('java', 'kotlin')

      -- Option 2: Use cindent for Kotlin (keeps kotlin highlighting, decent indent)
      vim.api.nvim_create_autocmd('FileType', {
        pattern = 'kotlin',
        callback = function()
          vim.bo.cindent = true
        end,
      })
    '';
  };
}
