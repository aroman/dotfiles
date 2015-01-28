" Because not everybody's a hipster
if &shell =~# 'fish$'
    set shell=sh
endif

" Use Vim defaults, not Vi's.
set nocompatible

" Kill swapfiles with fire
set noswapfile
set nobackup
set nowb

" Sane indentation defaults
set autoindent
set smartindent
set smarttab
set tabstop=4
set shiftwidth=4
set expandtab

" Shift+Tab to unindent
imap <S-Tab> <C-o><<

" BASH-like autocompletion
set wildmode=longest:full
set wildmenu

" Make backspace behave sanely
set backspace=2

" Highlight search things
set hlsearch

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
set pastetoggle=<F2>

" Vundle
if filereadable(expand("~/.vimrc.bundles"))
  source ~/.vimrc.bundles
endif

" Solarized love
syntax enable
colorscheme solarized
"set background=dark

" MacVim Font
set guifont=Monaco:h14
set guioptions-=r "scrollbar

" Airline customization
set noruler
set noshowmode
set statusline=
set laststatus=2
let g:airline_theme='solarized'
let g:airline_left_sep=''
let g:airline_right_sep=''

" Force myself to learn
" noremap  <Up>     <NOP>
" inoremap  <Down>   <NOP>
" inoremap  <Left>   <NOP>
" inoremap  <Right>  <NOP>
" noremap   <Up>     <NOP>
" noremap   <Down>   <NOP>
" noremap   <Left>   <NOP>
" noremap   <Right>  <NOP>
