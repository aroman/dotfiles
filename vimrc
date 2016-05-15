" Use Vim defaults, not Vi's.
set nocompatible

" Because not everybody's a hipster
if &shell =~# 'fish$'
    set shell=sh
endif

" Kill swapfiles with fire
set noswapfile
set nobackup
set nowb

" BASH-like autocompletion
set wildmode=longest:full
set wildmenu

" Allow backspace in insert mode
set backspace=indent,eol,start

" Highlight search things
set incsearch       " Find the next match as we type the search
set hlsearch        " Highlight searches by default
set ignorecase      " Ignore case when searching...
set smartcase       " ...unless we type a capital

" Wrapping
set nowrap       "Don't wrap lines
set linebreak    "Wrap lines at convenient points

" Scrolling
set scrolloff=8
set sidescrolloff=15
set sidescroll=1

" Bash like keys for the command line
cnoremap <C-A>      <Home>
cnoremap <C-E>      <End>

"" Unfuck my pinky [disabled]
"nore ; :
"nore , ;

" Line numbers
set number
set numberwidth=3
highlight LineNr cterm=bold

" 256-colors
set t_Co=256

" Sync X and Vim clipboards
" set clipboard=unnamedplus
set pastetoggle=<F2>
set paste

" Colors
syntax enable
silent! colorscheme bubblegum-256-dark
set background=dark

" Airline
set noruler
set noshowmode
set statusline=
set laststatus=2
let g:airline_theme='bubblegum'
let g:airline_left_sep=''
let g:airline_right_sep=''

" Folding
"set foldmethod=indent
"set foldnestmax=2
nnoremap <space> za
vnoremap <space> zf

" Automatically based on previous line
set autoindent

" re-open file to last line
if has("autocmd")
      au BufReadPost * if line("'\"") > 1 && line("'\"") <= line("$") | exe "normal! g'\"" | endif
endif

" Force myself to learn
" noremap  <Up>     <NOP>
" inoremap  <Down>   <NOP>
" inoremap  <Left>   <NOP>
" inoremap  <Right>  <NOP>
" noremap   <Up>     <NOP>
" noremap   <Down>   <NOP>
" noremap   <Left>   <NOP>
" noremap   <Right>  <NOP>

" Plugins
call plug#begin('~/.vim/plugged')

Plug 'tpope/vim-commentary'
Plug 'tpope/vim-sleuth'
Plug 'terryma/vim-multiple-cursors'
Plug 'bling/vim-airline'
Plug 'flazz/vim-colorschemes'
Plug 'vim-airline/vim-airline-themes'
Plug 'fatih/vim-go', { 'for': 'go' }
Plug 'elzr/vim-json', { 'for': 'json' }
Plug 'pangloss/vim-javascript', { 'for': 'js' }
Plug 'kchmck/vim-coffee-script', { 'for': 'coffee' }
Plug 'Matt-Deacalion/vim-systemd-syntax'

call plug#end()
