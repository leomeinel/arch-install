#!/bin/sh

/usr/bin/pacman -Qqen > /var/log/pkglist-explicit.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-explicit.pacman.log
/usr/bin/pacman -Qqem > /var/log/pkglist-foreign.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-foreign.pacman.log
pacman -Sl "aur" | awk '/installed.$/{print $2;}' /var/log/pkglist-aur.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-aur.pacman.log
pacman -Sl "home_ungoogled_chromium_Arch" | awk '/installed.$/{print $2;}' /var/log/pkglist-home_ungoogled_chromium_Arch.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-home_ungoogled_chromium_Arch.pacman.log
/usr/bin/pacman -Qqd > /var/log/pkglist-deps.pacman.log
/usr/bin/chmod 644 /var/log/pkglist-deps.pacman.log
