set encoding=utf-8
set nocompatible
filetype off

set rtp+=~/.vim/bundle/Vundle.vim
call vundle#begin()

Plugin 'Raimondi/delimitMate'
Plugin 'airblade/vim-gitgutter'
Plugin 'bling/vim-airline'
Plugin 'edsono/vim-matchit'
Plugin 'ervandew/supertab'
Plugin 'flazz/vim-colorschemes'
Plugin 'gmarik/Vundle.vim'
Plugin 'kchmck/vim-coffee-script'
Plugin 'kien/ctrlp.vim'
Plugin 'myusuf3/numbers.vim'
Plugin 'rking/ag.vim'
Plugin 'scrooloose/syntastic'
Plugin 'tpope/vim-commentary'
Plugin 'tpope/vim-endwise'
Plugin 'tpope/vim-fugitive'
Plugin 'tpope/vim-rails'
Plugin 'tpope/vim-surround'
Plugin 'vim-ruby/vim-ruby'
Plugin 'vim-scripts/bufkill.vim'

call vundle#end()

filetype indent on
syntax on

set shell=/bin/bash

set autoread
set updatetime=1000
autocmd CursorHoldI * silent w

set splitright
set splitbelow
set laststatus=2
set number

set hidden
set autoindent
set smartindent
set expandtab
autocmd BufWritePre * :%s/\s\+$//e

set tabstop=2
set softtabstop=2
set shiftwidth=2
set nowrap
set textwidth=80
set linebreak
set cursorline cursorcolumn
highlight ColorColumn ctermbg=magenta
call matchadd('ColorColumn', '\%81v', 100)

set nobackup
set noswapfile
set clipboard=unnamed

colors Monokai
let g:airline_powerline_fonts = 1
let g:airline_theme='molokai'

" CtrlP
set wildignore+=*/tmp/*
set wildignore+=vendor/bundle,vendor/ruby
set wildignore+=*.png,*.jpg,*.gif,*.gem,*.o,*.so,*.swp,*.zip,*.log
let g:ctrlp_custom_ignore = '\v[\/]\.(git|hg|svn)$'

" ejs syntax
au BufNewFile,BufRead *.ejs set filetype=html
