#!/usr/bin/env bash
###
# File: zz-arch-install.sh
# Author: Leopold Johannes Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Johannes Meinel & contributors
# SPDX ID: Apache-2.0
# URL: https://www.apache.org/licenses/LICENSE-2.0
###

# Set TMOUT of 1d
export TMOUT=86400

# Set umask
umask 027

# Disable coredumps
ulimit -c 0
