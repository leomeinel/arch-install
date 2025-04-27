#!/usr/bin/env bash
###
# File: zz-arch-install.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Set TMOUT of 1d
export TMOUT=86400

# Set umask
umask 027

# Disable coredumps
ulimit -c 0
