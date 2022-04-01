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

  nixpkgs.config.allowUnfree = true;

  home.packages = with pkgs; [
    fortune
    neovide
    ranger
    gimp
    visidata
    ripgrep-all
    discord
    wget
    firefox
    neofetch
    ranger
    spotify
    obsidian
    git
    zoom-us
    speedtest-cli
    pavucontrol
    synology-drive-client
    kitty
    slack
    k9s
    kubectl
    docker
    docker-compose
    ripgrep
    file
    ffmpeg
    imagemagickBig
    google-chrome
    killall
    ruby
    gnumake
    gcc
    bundix
    python-qt
    dig
    ldns # drill
    kubernetes-helm
    zathura
    xournalpp
    dropbox
    libreoffice
    unzip
    todoist-electron
    # findutils # For ranger
    mlocate # For ranger
    fzf # For ranger
    yt-dlp
    arduino
    kicad
    tmux
    mutt-wizard
    neomutt # mutt-wizard
    curl # mutt-wizard
    isync # mutt-wizard
    msmtp # mutt-wizard
    pass # mutt-wizard
    gnupg # mutt-wizard
    pinentry # mutt-wizard
    notmuch # mutt-wizard
    lieer # mutt-wizard
    w3m # mutt-wizard
    abook # mutt-wizard
    urlscan # mutt-wizard
    poppler_utils # mutt-wizard
    mailcap
    python38Packages.goobook # mutt
    awscli2
    python38Full
    python38Packages.wxPython_4_0
    hugo
    nodejs-16_x
    networkmanager-l2tp
    # qbittorrent
    # pywal
    steam
    wally-cli
    vlc
    # cubicsdr
    # sdrangel
    # gqrx
    # sdrpp-with-sdrplay
    # hamlib_4
    # wsjtx
    # unstable.element-desktop-wayland
    # blueberry
    # helvum
    duplicity
    signal-desktop
    ansible_2_10
    gcalcli
    # unstable.nix-template
    termdown
    httpie
    kubectx
    todoist
    peco # For todoist
    qalculate-gtk
    apprise
    pandoc
    nasc
    doctl
    qcad
    zip

    # For Sway
    # ---
    #sway
    #swaylock
    #swayidle
    #waybar
    #wl-clipboard
    #mako # notification daemon
    #rofi
    #rofi-calc
    ##wofi
    #wlsunset
    #pamixer
    #grim
    #swappy
    #slurp
    #clipman
    #brightnessctl
    #autotiling
    #wdisplays
    #copyq
    #kooha
    #wf-recorder
    #jq # For waybar weather
  ];

  # wayland.windowManager.sway = {
  #   enable = true;
  #   wrapperFeatures.gtk = true ;
  # };

  programs.zsh = {
    enable = true;
    enableCompletion = true;
    oh-my-zsh = {
      enable = true;
      theme = "robbyrussell";
      # theme = "powerlevel10k/powerlevel10k";
      plugins = [ "git" "ruby" "rails" "sudo" "kubectl" ];
    };

    # TODO: Need to source my p10k Properly
    # plugins = with pkgs; [
    #   {
    #     file = "powerlevel10k.zsh-theme";
    #     name = "powerlevel10k";
    #     src = pkgs.fetchFromGitHub {
    #       owner = "romkatv";
    #       repo = "powerlevel10k";
    #       rev = "v1.16.1";
    #       sha256 = "DLiKH12oqaaVChRqY0Q5oxVjziZdW/PfnRW1fCSCbjo=";
    #     };
    #   }
    #   {
    #     file = "p10k.zsh";
    #     name = "powerlevel10k-config";
    #     src = ./config/zsh/p10k;
    #   }
    # ];
  };

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

      set smartindent
      set autoindent
      filetype indent on
      set expandtab
      set shiftwidth=2
      set softtabstop=2
      set nowrap

      autocmd FileType mail setl tw=76|setl fo+=aw

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

  home.file = {
    "./.config/ranger".source = config.lib.file.mkOutOfStoreSymlink /home/jevin/.config/nixpkgs/ranger;

    ".config/sway/config".source = sway/config;
  };

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
        ExecStart = "/usr/bin/env duplicity_backup";
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

  home.shellAliases = {
    pomodoro = "termdown 25m -s -b";
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
