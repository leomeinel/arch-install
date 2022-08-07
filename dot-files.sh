#!/bin/sh

cd "$HOME"
git clone https://github.com/LeoMeinel/dot-files.git
chmod +x "$HOME"/dot-files/setup.sh
"$HOME"/dot-files/setup.sh
