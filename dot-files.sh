#!/usr/bin/env bash
###
# File: dot-files.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# INFO: This file is executed automatically during installation

# Fail on error
set -e

# Define functions
log_warning() {
    /usr/bin/logger -s -p local0.warning <<<"$(basename "${0}"): ${*}"
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Clone dot-files
DOT_FILES_DIR=~/.config/dot-files/
if [[ "${IS_RELEASE}" == "true" ]]; then
    git clone -b "${DOTFILES_VERSION}" https://github.com/leomeinel/dot-files.git "${DOT_FILES_DIR}"
else
    git clone -b games https://github.com/leomeinel/dot-files.git "${DOT_FILES_DIR}"
fi

# Append dot-files/install.conf
{
    echo "# arch-install"
    cat "${SCRIPT_DIR}"/install.conf
} >"${DOT_FILES_DIR}"/install.conf
chmod 755 "${DOT_FILES_DIR}"/setup.sh

# Run dot-files
"${DOT_FILES_DIR}"/setup.sh

# Merge changes to games in detached HEAD state because of using a tagged version
if [[ "${IS_RELEASE}" == "true" ]]; then
    cd "${DOT_FILES_DIR}"
    git switch -c tmp
    git checkout games
    git merge --no-gpg-sign --no-edit tmp ||
        log_warning "Couldn't merge changes to games. Please manually merge branch 'tmp' later."
fi
