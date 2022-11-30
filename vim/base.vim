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
" colorscheme base16-default-dark
colorscheme gruvbox

let g:indent_guides_enable_on_vim_startup = 1

set updatetime=100 "For Git marker updating to be faster

" Freedom
" nnoremap <Leader><Space> :Goyo<CR>

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

augroup HiglightTODO
    autocmd!
    autocmd WinEnter,VimEnter * :silent! call matchadd('Todo', 'TODO', -1)
augroup END

" xnoremap "+y y:call system("wl-copy", @")<cr>
" nnoremap "+p :let @"=substitute(system("wl-paste --no-newline"), '<C-v><C-m>', ''', 'g')<cr>p  
" nnoremap "*p :let @"=substitute(system("wl-paste --no-newline --primary"), '<C-v><C-m>', ''', 'g')<cr>p  
" For sway scratchpad
autocmd CursorHold .notes :write

" Resize splits when window size is changed
augroup AutoAdjustResize
  autocmd!
  autocmd VimResized * execute "normal! \<C-w>="
augroup end
