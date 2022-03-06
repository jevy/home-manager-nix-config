{ config, pkgs, duplicity_script, ... }:

{
  # Home Manager needs a bit of information about you and the
  # paths it should manage.
  # home.username = "jevin";
  # home.homeDirectory = "/home/jevin";

  # imports =
  #   [
  #     ./vim.nix
  #   ];

  home.packages = [
    pkgs.fortune
    pkgs.neovide
    pkgs.ranger
    duplicity_script.defaultPackage.x86_64-linux
  ];

  programs.neovim = {
    enable = true;
    viAlias = true;
    vimAlias = true;
    plugins = with pkgs.vimPlugins; [ vim-airline vim-surround vim-commentary vim-json vim-markdown goyo-vim ranger-vim base16-vim vim-nix];
    # settings = { 
    #   ignorecase = true;
    # };
    extraConfig = ''
      set mouse=a

      set nocompatible " explicitly get out of vi-compatible mode
      set nobackup
      set nowritebackup
      set noswapfile
      set incsearch
      set listchars=tab:>-,trail:- " show tabs and trailing
      set number " turn on line numbers
      set scrolloff=5 " Keep 10 lines (top/bottom) for scope
      set showmatch " show matching brackets
      set ignorecase " case insensitive by default
      " set autochdir " always switch to the current file directory
      " Proper completion (like bash)
      set wildmode=list:longest
      set linebreak
      set relativenumber

      " colorscheme Tomorrow-Night
      colorscheme base16-default-dark



      " Freedom
      nnoremap <Leader><Space> :Goyo<CR>

      " easy way to get out insert
      " noremap jj <ESC>

      " Spellcheck
      map <leader>s :setlocal spell! spelllang=en_ca<CR>

      " Do spell check in Latex
      augroup latexsettings
          autocmd FileType tex set spell
      augroup END


      " Highlight trailing whitespace
      highlight ExtraWhitespace ctermbg=red guibg=red
      match ExtraWhitespace /\s\+$/
      autocmd BufWinEnter * match ExtraWhitespace /\s\+$/
      autocmd InsertEnter * match ExtraWhitespace /\s\+\%#\@<!$/
      autocmd InsertLeave * match ExtraWhitespace /\s\+$/
      autocmd BufWinLeave * call clearmatches()
      autocmd Syntax * syn match ExtraWhitespace /\s\+$\| \+\ze\t/

      " TODO ADD THE REST
      set smartindent
      set autoindent
      filetype indent on
      set expandtab
      set shiftwidth=2
      set softtabstop=2

      augroup HiglightTODO
          autocmd!
          autocmd WinEnter,VimEnter * :silent! call matchadd('Todo', 'TODO', -1)
      augroup END

      " xnoremap "+y y:call system("wl-copy", @")<cr>  
      " nnoremap "+p :let @"=substitute(system("wl-paste --no-newline"), '<C-v><C-m>', ''', 'g')<cr>p  
      " nnoremap "*p :let @"=substitute(system("wl-paste --no-newline --primary"), '<C-v><C-m>', ''', 'g')<cr>p  
      " For sway scratchpad
      autocmd CursorHold .notes :write
    '';
  };

  home.file."./.config/ranger".source = config.lib.file.mkOutOfStoreSymlink /home/jevin/.config/nixpkgs/ranger;

  systemd.user.services = {
    jevin_backup = {
      Unit = {
        Description = "Backup Jevin's Directory with Duplicity";
      };
      Install = {
        WantedBy = [ "default.target" ];
      };
      Service = {
        Type = "oneshot";
        ExecStart = "duplicity_backup";
      };
    };
  };

  systemd.user.timers = {
    jevin_backup_timer = {
      Unit = {
        Description = "Run Jevin's Duplicity Backup";
      };
        Install = {
          WantedBy = [ "timers.target" ];
        };
      Timer = {
        OnUnitActiveSec = "24h"; # 24 hours since it was run last
        Unit = "jevin_backup.service";
      };
    };
  };


  # This value determines the Home Manager release that your
  # configuration is compatible with. This helps avoid breakage
  # when a new Home Manager release introduces backwards
  # incompatible changes.
  #
  # You can update Home Manager without changing this value. See
  # the Home Manager release notes for a list of state version
  # changes in each release.
  home.stateVersion = "21.11";

  # Let Home Manager install and manage itself.
  programs.home-manager.enable = true;
  # programs.home-manager.useGlobalPkgs = true;

  programs.git = {
    enable = true;
    userName = "jevin";
    userEmail = "jevin@quickjack.ca";
    aliases = {
      st = "status";
    };
  };

}
