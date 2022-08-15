#!/bin/sh

# Fail on error
set -e

# Run dot-files/setup.sh
cd
git clone https://github.com/LeoMeinel/dot-files.git
chmod +x ~/dot-files/setup.sh
~/dot-files/setup.sh
