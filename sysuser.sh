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

# Set variables
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "$0")")"

# Set up post.sh
cp "$SCRIPT_DIR/pkgs-post.txt" ~/
cp "$SCRIPT_DIR/post.sh" ~/
cp "$SCRIPT_DIR/install.conf" ~/
chmod +x ~/post.sh

# Create backup directory
mkdir -p ~/backup

# Configure anacron user jobs
mkdir -p ~/.anacron/{etc,spool,etc/cron.daily,etc/cron.weekly,etc/cron.monthly}
{
    echo '# .anacron/etc/anacrontab: user configuration file for anacron'
    echo ''
    echo '# See anacron(8) and anacrontab(5) for details.'
    echo ''
    echo 'SHELL=/bin/sh'
    echo 'PATH=/usr/local/sbin:/usr/local/bin:/sbin:/bin:/usr/sbin:/usr/bin'
    echo "MAILTO=$(whoami)"
    echo '# the maximum random delay added to the base delay of the jobs'
    echo 'RANDOM_DELAY=45'
    echo '# the jobs will be started during the following hours only'
    echo 'START_HOURS_RANGE=3-22'
    echo ''
    echo '#period in days   delay in minutes   job-identifier   command'
    echo '1 5 cron.daily nice run-parts $HOME/.anacron/etc/cron.daily'
    echo '7 25 cron.weekly nice run-parts $HOME/.anacron/etc/cron.weekly'
    echo '@monthly 45 cron.monthly nice run-parts $HOME/.anacron/etc/cron.monthly'
} >~/.anacron/etc/anacrontab
(
    crontab -l 2>/dev/null
    echo '@hourly /usr/bin/anacron -s -t $HOME/.anacron/etc/anacrontab -S $HOME/.anacron/spool'
) | crontab -

# Remove repo
rm -rf ~/git
