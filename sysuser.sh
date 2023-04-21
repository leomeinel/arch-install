#!/bin/bash
###
# File: sysuser.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2023 Leopold Meinel & contributors
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
cp /git/arch-install/pkgs-post.txt ~/
cp /git/arch-install/post.sh ~/
cp /git/arch-install/install.conf ~/
chmod +x ~/post.sh

# Remove repo
rm -rf ~/git
