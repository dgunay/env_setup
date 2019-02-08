""""""""""""""""""""""""""""
" Devin's Vim configuration
""""""""""""""""""""""""""""

" Tab = 2 spaces 
set tabstop=2
set shiftwidth=2
set expandtab

" Be smart when using tabs ;)
set smarttab

" :W sudo saves the file 
" (useful for handling the permission-denied error)
command W w !sudo tee % > /dev/null
