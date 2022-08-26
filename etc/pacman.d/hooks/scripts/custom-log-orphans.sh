#!/bin/sh

PKGS="$(/usr/bin/pacman -Qtdq)"
if [ -n "$PKGS" ]
then
  {
    /usr/bin/echo "The following packages are installed but not required (anymore): "
    /usr/bin/echo "$PKGS"
    /usr/bin/echo "You can remove them all using 'pacman -Qtdq | pacman -Rns -'"
  }
fi
