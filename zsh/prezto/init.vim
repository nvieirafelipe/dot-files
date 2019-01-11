call plug#begin('~/.local/share/nvim/plugged')

" Only works on OS X
" Plug '/usr/local/opt/fzf'
Plug 'airblade/vim-gitgutter'
Plug 'dracula/vim'
Plug 'elixir-lang/vim-elixir'
Plug 'ervandew/supertab'
Plug 'jiangmiao/auto-pairs'
Plug 'junegunn/fzf', { 'dir': '~/.fzf', 'do': './install --all' }
Plug 'junegunn/fzf.vim'
Plug 'leafgarland/typescript-vim'
Plug 'mhinz/vim-startify'
Plug 'mustache/vim-mustache-handlebars'
Plug 'myusuf3/numbers.vim'
Plug 'rust-lang/rust.vim'
Plug 'shumphrey/fugitive-gitlab.vim'
Plug 'scrooloose/syntastic'
Plug 'tpope/vim-endwise'
Plug 'tpope/vim-fugitive'
Plug 'tpope/vim-rails'
Plug 'tpope/vim-rhubarb'
Plug 'tpope/vim-surround'
Plug 'vim-airline/vim-airline'
Plug 'vim-airline/vim-airline-themes'
Plug 'vim-scripts/indentpython.vim'

call plug#end()

set shell=/bin/sh
syntax on
color dracula

set expandtab
set shiftwidth=2
set softtabstop=2
set list
autocmd BufWritePre * :%s/\s\+$//e

set nowrap
set cursorline cursorcolumn
hi OverLength ctermfg=black ctermbg=darkgray
match OverLength /\%>90v.\+/

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

" Startify
autocmd FileType startify setlocal cursorline cursorcolumn
let g:startify_bookmarks = [{ 'n': '~/.config/nvim/init.vim' }]
"

" Syntastic
set statusline+=%#warningmsg#
set statusline+=%{SyntasticStatuslineFlag()}
set statusline+=%*

let g:syntastic_always_populate_loc_list = 1
let g:syntastic_auto_loc_list = 1
let g:syntastic_check_on_open = 1
let g:syntastic_check_on_wq = 0
let g:syntastic_eruby_ruby_quiet_messages =
  \ {"regex": "possibly useless use of .* in void context"}

let g:syntastic_sh_shellcheck_args = "-x"
"

" *.arb files
autocmd BufRead,BufNewFile *.arb setfiletype ruby
"

" fzf
command! -bang -nargs=* Rg
  \ call fzf#vim#grep(
  \   'rg --column --line-number --no-heading --color=always '.shellescape(<q-args>), 1,
  \   fzf#vim#with_preview(),
  \   <bang>0)

command! -bang -nargs=? -complete=dir Files
  \ call fzf#vim#files(
  \   <q-args>,
  \   fzf#vim#with_preview(),
  \   <bang>0)

" fugitive-gitlab
" let g:fugitive_gitlab_domains = ['https://somegitlab.com']

map <C-n> :Lexplore<cr>
nmap <C-n> :Lexplore<cr>
map <C-p> :Files<cr>
nmap <C-p> :Files<cr>
map <C-l> :Commits<cr>
nmap <C-l> :Commits<cr>
map <C-f> :Rg<cr>
nmap <C-f> :Rg<cr>
map <C-h> :History<cr>
nmap <C-h> :History<cr>
map <C-b> :Buffers<cr>
nmap <C-b> :Buffers<cr>
