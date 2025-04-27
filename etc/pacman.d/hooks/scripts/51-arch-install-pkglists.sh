#!/usr/bin/env bash
###
# File: 51-arch-install-pkglists.sh
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# Define functions
print_header() {
    /usr/bin/echo ""
    /usr/bin/echo "########################"
    /usr/bin/date -u +"#%Y-%m-%dT%H:%M:%S %Z"
    /usr/bin/echo "########################"
}

# Append pkglists
if [[ -n "$(/usr/bin/pacman -Qen)" ]] >/dev/null 2>&1; then
    file=/var/log/pkglist-explicit.pacman.log
    tmpfile="$(/usr/bin/mktemp /tmp/"$(/usr/bin/basename "${0}")"-XXXXXX)"
    cp "${file}" "${tmpfile}"
    {
        /usr/bin/cat "${tmpfile}"
        print_header
        /usr/bin/pacman -Qen
    } | /usr/bin/awk '/^#/ || !NF || !seen[$0]++' >"${file}"
    SUCCESS="true"
fi
if [[ -n "$(/usr/bin/pacman -Qem)" ]] >/dev/null 2>&1; then
    file=/var/log/pkglist-foreign.pacman.log
    tmpfile="$(/usr/bin/mktemp /tmp/"$(/usr/bin/basename "${0}")"-XXXXXX)"
    cp "${file}" "${tmpfile}"
    {
        /usr/bin/cat "${tmpfile}"
        print_header
        /usr/bin/pacman -Qem
    } | /usr/bin/awk '/^#/ || !NF || !seen[$0]++' >"${file}"
    SUCCESS="true"
fi
if [[ -n "$(/usr/bin/pacman -Qd)" ]] >/dev/null 2>&1; then
    file=/var/log/pkglist-deps.pacman.log
    tmpfile="$(/usr/bin/mktemp /tmp/"$(/usr/bin/basename "${0}")"-XXXXXX)"
    cp "${file}" "${tmpfile}"
    {
        /usr/bin/cat "${tmpfile}"
        print_header
        /usr/bin/pacman -Qd
    } | /usr/bin/awk '/^#/ || !NF || !seen[$0]++' >"${file}"
    SUCCESS="true"
fi

# Fail only if none of the commands have succeeded
if [[ -n "${SUCCESS}" ]]; then
    exit 0
else
    exit 1
fi
