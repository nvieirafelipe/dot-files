set encoding=utf-8
set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'airblade/vim-gitgutter'
Plugin 'edsono/vim-matchit'
Plugin 'elixir-lang/vim-elixir'
Plugin 'ervandew/supertab'
Plugin 'flazz/vim-colorschemes'
Plugin 'gmarik/Vundle.vim'
Plugin 'kchmck/vim-coffee-script'
Plugin 'kien/ctrlp.vim'
Plugin 'lambdatoast/elm.vim'
Plugin 'mhinz/vim-startify'
Plugin 'mustache/vim-mustache-handlebars'
Plugin 'myusuf3/numbers.vim'
Plugin 'posva/vim-vue'
Plugin 'othree/html5.vim'
Plugin 'Raimondi/delimitMate'
Plugin 'rking/ag.vim'
Plugin 'scrooloose/syntastic'
Plugin 'tpope/vim-endwise'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-haml'
Plugin 'tpope/vim-liquid'
Plugin 'tpope/vim-rails'
Plugin 'tpope/vim-surround'
Plugin 'vim-airline/vim-airline'
Plugin 'vim-airline/vim-airline-themes'

call vundle#end()

filetype indent on
syntax on

set shell=/bin/bash

set autoread

set splitright
set splitbelow
set laststatus=2
set number

set hidden
set autoindent
set smartindent
set expandtab
autocmd BufWritePre * :%s/\s\+$//e

set list
set tabstop=2
set softtabstop=2
set shiftwidth=2
set nowrap
set textwidth=0
set wrapmargin=0
set linebreak
set cursorline cursorcolumn
highlight ColorColumn ctermbg=magenta
call matchadd('ColorColumn', '\%81v', 100)

set nobackup
set noswapfile
set clipboard+=unnamedplus

colors Monokai
let g:airline_powerline_fonts = 1
let g:airline_theme='molokai'

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

" CtrlP
let g:ctrlp_user_command='cd %s && git ls-files -co --exclude-standard'
set wildignore+=*/bower_components/*,*/dist/*,*/node_modules/*,*/tmp/*
set wildignore+=*/vendor/*,*/deps/*,*/_build/*
set wildignore+=*.png,*.jpg,*.gif,*.gem,*.o,*.so,*.swp,*.zip,*.log,*.pyc
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'

" Netrw
let g:netrw_list_hide='.*\.pyc'

" ejs syntax
au BufNewFile,BufRead *.ejs set filetype=html

" snippets
let g:UltiSnipsExpandTrigger="<tab>"
let g:UltiSnipsJumpForwardTrigger="<c-b>"
let g:UltiSnipsJumpBackwardTrigger="<c-z>"

let g:netrw_liststyle=3
