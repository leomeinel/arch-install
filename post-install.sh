#!/bin/sh

set -e
sudo sed -i 's/#LocalRepo/LocalRepo/;s/#Chroot/Chroot/;s/#RemoveMake/RemoveMake/;s/#CleanAfter/CleanAfter/' /etc/paru.conf
paru -S --noprogressbar --noconfirm --needed librewolf-bin ungoogled-chromium chromium-extension-web-store sweet-kde-theme-git papirus-icon-theme snap-pac-grub pacman-log-orphans-hook snapper-gui-git
paru -Syu --noprogressbar --noconfirm
paru -Scc --noprogressbar --noconfirm
