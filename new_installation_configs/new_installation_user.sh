#!/bin/bash

git clone https://github.com/tanerguven/conf.git $1 || exit

# conkeror
ln -sf $1/conkerorrc ~/.conkerorrc

# emacs
rm ~/.emacs
mkdir -p ~/.emacs.d/
ln -sf $1/emacs-configuration ~/.emacs.d/
ln -sf ~/.emacs.d/emacs-configuration/init-global.el ~/.emacs

# ratpoison
ln -sf $1/ratpoison-configuration/ratpoison ~/.ratpoison
ln -sf $1/ratpoison-configuration/ratpoisonrc ~/.ratpoisonrc

# xscreensaver
ln -sf $1/xscreensaver ~/.xscreensaver

# compile configuration
CURDIR=`pwd`
cd $1/emacs-configuration/;
make;
cd $CURDIR
