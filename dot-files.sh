#!/usr/bin/env bash

# NOTE: This file is executed automatically during installation

# Fail on error
set -eu

# Define functions
log_warning() {
    /usr/bin/logger -s -p local0.warning <<<"$(basename "${0}"): ${*}"
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
set -a
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.env
set +a

# Clone dot-files
if [[ "${IS_RELEASE}" == "true" ]]; then
    chezmoi init --branch "${DOTFILES_VERSION}" https://github.com/leomeinel/dot-files.git
else
    chezmoi init --branch main https://github.com/leomeinel/dot-files.git
fi

# Configure dot-files
CHEZMOI_PATH=~/.local/share/chezmoi
#shellcheck disable=SC2016
tomlq -ti '
    .data.sysuser = $ENV.SYSUSER |
    .data.keylayout = $ENV.KEYLAYOUT |
    .data.git_email = $ENV.GIT_EMAIL |
    .data.git_name = $ENV.GIT_NAME |
    .data.git_signingkey = $ENV.GIT_SIGNINGKEY |
    .data.git_gpgsign = $ENV.GIT_GPGSIGN |
    .data.backlight_device = $ENV.BACKLIGHT_DEVICE |
    .data.sway_autostart = $ENV.SWAY_AUTOSTART |
    .data.sway_output = $ENV.SWAY_OUTPUT
' "${CHEZMOI_PATH}"/home/.chezmoi.toml.tmpl
if [[ "${IS_RELEASE}" == "true" ]]; then
    cd "${CHEZMOI_PATH}"
    git switch -c tmp
    git checkout main
    git merge --no-gpg-sign --no-edit tmp ||
        log_warning "Couldn't merge changes to main. Please manually merge branch 'tmp' later."
fi

# Reinitialize chezmoi to apply config changes and apply
chezmoi init
chezmoi apply
