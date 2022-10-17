#!/bin/bash
###
# File: sysuser.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2022 Leopold Meinel & contributors
# SPDX ID: GPL-3.0-or-later
# URL: https://www.gnu.org/licenses/gpl-3.0-standalone.html
# -----
###

# Fail on error
set -eu

# Configure ~/.config/autostart/apparmor-notify.desktop
mkdir -p ~/.config/autostart
{
    echo "[Desktop Entry]"
    echo "Type=Application"
    echo "Name=AppArmor Notify"
    echo "Comment=Receive on screen notifications of AppArmor denials"
    echo "TryExec=aa-notify"
    echo "Exec=aa-notify -p -s 1 -w 60 -f /var/log/audit/audit.log"
    echo "StartupNotify=false"
    echo "NoDisplay=true"
} >~/.config/autostart/apparmor-notify.desktop

# Set up post.sh
git clone https://github.com/LeoMeinel/arch-install.git ~/git/arch-install
mv ~/git/arch-install/pkgs-post.txt ~/
mv ~/git/arch-install/post.sh ~/
sed -i 's/<INSERT_SYSUSER>/'"$1"'/;s/<INSERT_VIRTUSER>/'"$2"'/;s/<INSERT_HOMEUSER>/'"$3"'/;s/<INSERT_GUESTUSER>/'"$4"'/' ~/post.sh
chmod +x ~/post.sh

# Remove repo
rm -rf ~/git
