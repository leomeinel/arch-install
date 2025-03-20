#!/usr/bin/env bash
###
# File: 96-systemd-boot-sign.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

set -eu

/usr/local/bin/cryptboot systemd-boot-sign
