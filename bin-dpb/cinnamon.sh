#!/bin/bash

# view via: dconf dump /

gsettings set org.cinnamon.desktop.session idle-delay 0
gsettings set org.cinnamon.desktop.screensaver lock-enabled false

gsettings set org.cinnamon.desktop.keybindings.media-keys terminal "['<Primary><Alt>t', '<Primary><Super>s', '<Super>Return']"
gsettings set org.cinnamon.desktop.keybindings.media-keys www "['XF86WWW', '<Primary><Alt>c']"
gsettings set org.cinnamon.desktop.keybindings.custom-keybindings/custom0 binding "['<Primary><Alt>x']"
gsettings set org.cinnamon.desktop.keybindings.custom-keybindings/custom0 command "/bin/bash -ilc /usr/bin/emacs"
gsettings set org.cinnamon.desktop.keybindings.custom-keybindings/custom0 name "Emacs"
