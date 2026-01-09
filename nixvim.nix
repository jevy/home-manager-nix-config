{
  config,
  pkgs,
  pkgsWithUnfree ? pkgs,
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
    # Use extraPlugins with pkgsWithUnfree to handle unfree license
    extraPlugins = [
      pkgsWithUnfree.vimPlugins.claude-code-nvim
    ];
    keymaps = [
      # Escape insert mode with jj
      { mode = "i"; key = "jj"; action = "<Esc>"; options = { silent = true; desc = "Escape insert mode"; }; }
      # Flash: jump (using f instead of s, giving up native f)
      { mode = ["n" "x" "o"]; key = "f"; action.__raw = "function() require('flash').jump() end"; options = { silent = true; desc = "Flash"; }; }
      # Flash: treesitter selection
      { mode = ["n" "x" "o"]; key = "F"; action.__raw = "function() require('flash').treesitter() end"; options = { silent = true; desc = "Flash Treesitter"; }; }
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
      # Claude Code keymaps
      { mode = "n"; key = "<leader>ac"; action = "<cmd>ClaudeCode<cr>"; options = { silent = true; desc = "Toggle Claude"; }; }
      { mode = "n"; key = "<leader>af"; action = "<cmd>ClaudeCodeFocus<cr>"; options = { silent = true; desc = "Focus Claude"; }; }
      { mode = "n"; key = "<leader>ar"; action = "<cmd>ClaudeCode --resume<cr>"; options = { silent = true; desc = "Resume Claude"; }; }
      { mode = "n"; key = "<leader>am"; action = "<cmd>ClaudeCodeSelectModel<cr>"; options = { silent = true; desc = "Select Claude model"; }; }
      { mode = "v"; key = "<leader>as"; action = "<cmd>ClaudeCodeSend<cr>"; options = { silent = true; desc = "Send to Claude"; }; }
    ];
    plugins = {
      gitgutter.enable = true;
      lualine.enable = true;
      flash = {
        enable = true;
        settings = {
          label.min_pattern_length = 1;
          jump.autojump = true;
          modes = {
            # Disable char mode since we're using f for flash jump
            char.enabled = false;
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
          surround = {};  # sa/sd/sr (s is free now)
        };
      };
      snacks = {
        enable = true;
        # Required by claude-code for terminal support
      };
      # claude-code: using extraPlugins due to unfree license issues with nixvim's built-in plugin
      # claude-code = {
      #   enable = true;
      #   settings = {
      #     terminal = {
      #       split_side = "right";
      #       split_width_percentage = 0.35;
      #     };
      #   };
      # };
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

      -- Claude Code setup (via extraPlugins)
      require('claude-code').setup({
        terminal = {
          split_side = "right",
          split_width_percentage = 0.35,
        },
      })
    '';
  };
}
