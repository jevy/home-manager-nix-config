{
  config,
  pkgs,
  lib,
  ...
}: {
  # home.file.luacheckrc = {
  #   target = ".luacheckrc";
  #   executable = false;
  #   text = ''
  #     read_globals = {
  #       "vim",
  #     }
  #   '';
  # };

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    vimdiffAlias = true;
    defaultEditor = true;
    plugins = with pkgs.vimPlugins; [
      vim-airline
      # vim-surround
      # vim-commentary
      vim-json
      vim-markdown
      # goyo-vim
      # ranger-vim
      base16-vim
      vim-nix
      gruvbox-material
      vim-gitgutter
      nvim-tree-lua
      nvim-web-devicons
      fzf-vim
      vim-rooter
      vim-easy-align
      vim-dirdiff
      vim-fugitive
      # rnvimr
      leap-nvim
      indent-blankline-nvim
      rainbow-delimiters-nvim
      vim-cool # Turn off highlighting after a search
      vim-tmux-navigator
      (pkgs.vimUtils.buildVimPlugin {
        name = "which-key";
        src = pkgs.fetchFromGitHub {
          owner = "folke";
          repo = "which-key.nvim";
          rev = "v3.13.2";
          sha256 = "nv9s4/ax2BoL9IQdk42uN7mxIVFYiTK+1FVvWDKRnGM=";
        };
      })

      (pkgs.vimPlugins.nvim-treesitter.withPlugins (p: [
        p.ruby
        p.nix
        p.regex
        p.yaml
        # p.json # Failed to build
        p.markdown
        p.dockerfile
        p.lua
        p.javascript
        p.typescript
        p.latex
        p.c
        p.vimdoc
        p.json
        p.html
      ]))

      # completion-treesitter
      nvim-treesitter-textobjects
      nvim-treesitter-context
      # vim-lsp
      nvim-lspconfig

      # Text completion
      cmp-nvim-lsp
      nvim-cmp
      ultisnips

      # Formatting
      efmls-configs-nvim

      lspsaga-nvim # LSP Navigation

      plenary-nvim
      telescope-nvim
      telescope-fzy-native-nvim
      (pkgs.vimUtils.buildVimPlugin {
        name = "vim-ai";
        src = pkgs.fetchFromGitHub {
          owner = "madox2";
          repo = "vim-ai";
          rev = "4692eec84b5aa9d95256bef515bd1d17471e5570";
          sha256 = "YRN8aJX7TG1qX89JgfzE1oBhU7dncC3LJov7+kFbOg8="; # Replace with the correct SHA256 hash
        };
      })
    ];

    extraPackages = with pkgs; [
      tree-sitter
      nodePackages.typescript-language-server
      efm-langserver # Formatting and Linting
      # luajitPackages.luacheck # Lua Linting
      stylua # Lua Formating
      alejandra # Nix formating
      nodePackages.eslint # Typescript
      nodePackages.prettier # HTML
      nil # Nix LSP
      lua-language-server # lua lsp
      solargraph
      # ltex-ls
      terraform-ls
    ];

    extraConfig = builtins.concatStringsSep "\n" [
      ''
        lua << EOF
        ${builtins.readFile ./neovim-setup.lua}
        EOF
      ''
    ];
  };
}
