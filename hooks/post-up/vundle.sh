#!/bin/sh

if [ ! -e $HOME/.vim/bundle/vundle ]; then
  git clone https://github.com/gmarik/Vundle.vim.git $HOME/.vim/bundle/vundle
fi
vim -u $HOME/.vimrc.bundles +PluginInstall +qa
