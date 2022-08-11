#!/bin/sh

set -e
cd
git clone https://github.com/LeoMeinel/dot-files.git
chmod +x ~/dot-files/setup.sh
~/dot-files/setup.sh
