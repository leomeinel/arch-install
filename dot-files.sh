#!/bin/sh

# Fail on error
set -e

# Run dot-files/setup.sh
git clone https://github.com/LeoMeinel/dot-files.git ~/dot-files
chmod +x ~/dot-files/setup.sh
~/dot-files/setup.sh
