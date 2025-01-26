{
  config,
  pkgs,
  ...
}: {
  # ixpkgs.config.allowUnfreePredicate = (pkg: true);

  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "24.11";

  # Let Home Manager install and manage itself.
  # programs.home-manager.enable = true;

  home.keyboard = {
    layout = "us";
    variant = "qwerty";
    options = ["ctrl:nocaps"];
  };
  programs.git = {
    enable = true;
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    difftastic.enable = true;
  };

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

  sops = {
    age.keyFile = "/home/jevin/.config/sops/age/keys.txt"; # must have no password!

    defaultSopsFile = ./secrets.yaml;

    secrets.openai_api_key = {
      path = "${config.sops.defaultSymlinkPath}/openai_api_key";
    };
    secrets.anthropic_api_key = {
      path = "${config.sops.defaultSymlinkPath}/anthropic_api_key";
    };
  };
}
