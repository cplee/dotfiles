#!/bin/zsh

set -e

### Download dotfiles
[ -d ${ZDOTDIR:-$HOME}/.zprezto ] || git clone --recursive https://github.com/cplee/dotfiles.git "${ZDOTDIR:-$HOME}/.zprezto"

### Link dotfiles
${ZDOTDIR:-$HOME}/.zprezto/link.sh


### Install Brew bundles
case `uname` in 
  'Darwin')
    brew -v || /usr/bin/ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
    brew bundle --file ${ZDOTDIR:-$HOME}/.zprezto/Brewfile
    ;;
  *)
    ;;
esac


sudo chsh -s /bin/zsh $USER

# update vim
vim +PluginInstall +qall
