call plug#begin('~/.local/share/nvim/plugged')

Plug 'airblade/vim-gitgutter'
Plug 'dracula/vim'
Plug 'jiangmiao/auto-pairs'
Plug '/usr/local/opt/fzf'
Plug 'junegunn/fzf.vim'
Plug 'myusuf3/numbers.vim'
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'

call plug#end()

syntax on
color dracula

set expandtab
set shiftwidth=2
set softtabstop=2
set list

set nowrap
set cursorline cursorcolumn

set splitright
set splitbelow
set laststatus=2
set number

set nobackup noswapfile
set clipboard+=unnamedplus

" Transparency
hi Normal             ctermbg=NONE
hi Statement          ctermbg=NONE
hi Title              ctermbg=NONE
hi Todo               ctermbg=NONE
hi Underlined         ctermbg=NONE
hi ErrorMsg           ctermbg=NONE
hi LineNr             ctermbg=NONE
hi TabLineFill        ctermbg=NONE
hi NonText            ctermbg=NONE
"

" airline
let g:airline_powerline_fonts = 1
let g:airline_theme='dracula'
"

" Netrw
let g:netrw_liststyle=3
let g:netrw_list_hide='.*\.pyc'
"

" Syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
"

" fzf
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column -uu --line-number --no-heading --color=always '.shellescape(<q-args>), 1,
  \   fzf#vim#with_preview(),
  \   <bang>0)

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(<q-args>, fzf#vim#with_preview(), <bang>0)

map <C-n> :Lexplore<cr>
nmap <C-n> :Lexplore<cr>
map <C-p> :Files<cr>
nmap <C-p> :Files<cr>
map <C-l> :Commits<cr>
nmap <C-l> :Commits<cr>
map <C-f> :Rg<cr>
nmap <C-f> :Rg<cr>
map <C-b> :Buffers<cr>
nmap <C-b> :Buffers<cr>
"
