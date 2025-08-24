#!/usr/bin/env bash
###
# File: setup.sh
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
log_err() {
    /usr/bin/logger -s -p local0.err <<<"$(basename "${0}"): ${*}"
}
log_warning() {
    /usr/bin/logger -s -p local0.warning <<<"$(basename "${0}"): ${*}"
}
sed_exit() {
    log_err "'sed' didn't replace, report this at https://github.com/leomeinel/arch-install/issues."
    exit 1
}
var_invalid_err_exit() {
    log_err "'${1}' is invalid in '${2}'."
    exit 1
}
var_invalid_warning() {
    log_warning "'${1}' is invalid in '${2}'."
}

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Mount /etc/fstab
mount -a

# Sync files from this repo to system
rsync -rq "${SCRIPT_DIR}/etc/" /etc
rsync -rq "${SCRIPT_DIR}/usr/" /usr
rsync -rq "${SCRIPT_DIR}/efi/" /efi

# Add groups & users
## Configure login.defs
## START sed
FILE=/etc/login.defs
### YESCRYPT_COST_FACTOR is currently commented out, that's why we don't exit if it fails
STRING="^YESCRYPT_COST_FACTOR"
grep -q "${STRING}" "${FILE}" || true
sed -i "s/${STRING}/#YESCRYPT_COST_FACTOR/g" "${FILE}" || true
STRING="^UMASK"
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s/${STRING}/#UMASK/g" "${FILE}"
STRING="^HOME_MODE"
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s/${STRING}/#HOME_MODE/g" "${FILE}"
## END sed
{
    echo ""
    echo "# arch-install"
    echo "YESCRYPT_COST_FACTOR 11"
    echo "UMASK 027"
    echo "HOME_MODE 0700"
    echo "SHA_CRYPT_MIN_ROUNDS 99999999"
    echo "SHA_CRYPT_MAX_ROUNDS 999999999"
} >>"${FILE}"
## Configure /etc/default/useradd
## START sed
FILE=/etc/default/useradd
STRING="^SHELL="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s/${STRING}/#SHELL=/g" "${FILE}"
## END sed
{
    echo ""
    echo "# arch-install"
    echo "SHELL=/bin/bash"
} >>"${FILE}"
groupadd -r audit
groupadd -r libvirt
groupadd -r usbguard
groupadd -r ssh-allow
[[ -n "${SYSUSER}" ]] ||
    {
        log_err "'SYSUSER' has to be specified."
        exit 1
    }
useradd -ms /bin/bash -G adm,audit,log,proc,rfkill,ssh-allow,sys,systemd-journal,usbguard,wheel,video "${SYSUSER}"
[[ -n "${GUESTUSER}" ]] &&
    useradd -ms /bin/bash -G video "${GUESTUSER}"
[[ -n "${HOMEUSER}" ]] &&
    useradd -ms /bin/bash -G video "${HOMEUSER}"
[[ -n "${VIRTUSER}" ]] &&
    useradd -ms /bin/bash -G libvirt,video "${VIRTUSER}"
[[ -n "${WORKUSER}" ]] &&
    useradd -ms /bin/bash -G libvirt,video "${WORKUSER}"
echo "#################################################################"
echo "#                      _    _           _   _                   #"
echo "#                     / \  | | ___ _ __| |_| |                  #"
echo "#                    / _ \ | |/ _ \ '__| __| |                  #"
echo "#                   / ___ \| |  __/ |  | |_|_|                  #"
echo "#                  /_/   \_\_|\___|_|   \__(_)                  #"
echo "#                                                               #"
echo "#       It is mandatory to choose a password matching the       #"
echo "#                       following specs:                        #"
echo "#                    At least 12 characters,                    #"
echo "#           at least 1 digit, 1 uppercase character,            #"
echo "#         1 lowercace character and 1 other character.          #"
echo "#################################################################"
for user in "${USERS[@]}"; do
    [[ -n "${user}" ]] ||
        continue
    id "${user}" >/dev/null 2>&1 ||
        var_invalid_err_exit "${user}" "USERS"
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        echo "Enter password for ${user}"
        if passwd "${user}"; then
            break
        else
            log_warning "You have entered an incorrect password. Retrying now."
        fi
    done
done

# Configure /etc before installing packages
## Configure locale
FILE=/etc/locale.gen
{
    echo ""
    echo "# arch-install"
} >>"${FILE}"
for locale in "${LOCALES[@]}"; do
    grep -q "^#${locale}" /etc/locale.gen ||
        var_invalid_err_exit "${locale}" "LOCALES"
    echo "${locale}" >>"${FILE}"
done
locale-gen
## Configure /etc/doas.conf
chmod 0400 /etc/doas.conf
## Configure pacman hooks in /etc/pacman.d/hooks
DISK1="$(lsblk -npo PKNAME "$(findmnt -no SOURCE --target /efi)" | tr -d "[:space:]")"
DISK1P2="$(lsblk -rnpo TYPE,NAME "${DISK1}" | grep "part" | sed 's/part//g' | sed -n '2p' | tr -d "[:space:]")"
lsblk -rno TYPE "${DISK1P2}" | grep -q "raid1" &&
    rsync -rq "${SCRIPT_DIR}/dynamic-deploy/etc/pacman.d/hooks/" /etc/pacman.d/hooks
chmod 755 /etc/pacman.d/hooks/scripts/*.sh
## Configure /etc/pacman.conf
{
    echo ""
    echo "# arch-install"
    echo "Include = /etc/pacman.conf.d/*.conf"
} >>/etc/pacman.conf
## Configure /etc/xdg/reflector/reflector.conf and update mirrors
{
    echo "--save /etc/pacman.d/mirrorlist"
    echo "--country ${MIRRORCOUNTRIES}"
    echo "--protocol https"
    echo "--latest 20"
    echo "--sort rate"
} >/etc/xdg/reflector/reflector.conf
pacman-key --init
reflector --save /etc/pacman.d/mirrorlist --country "${MIRRORCOUNTRIES}" --protocol https --latest 20 --sort rate

# Install packages
for i in {1..5}; do
    if [[ "${i}" -eq 5 ]]; then
        log_err "Too many retries."
        exit 1
    fi
    if pacman -Syu --noprogressbar --noconfirm --needed - <"${SCRIPT_DIR}/pkgs-setup.txt"; then
        break
    else
        log_warning "'pacman' failed. Retrying now."
    fi
done
## Install optional dependencies
DEPENDENCIES=""
pacman -Qq "apparmor" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\npython-notify2\npython-psutil'
pacman -Qq "inkcape" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\npython-tinycss2'
pacman -Qq "libvirt" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ndnsmasq'
pacman -Qq "open-vm-tools" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ngtkmm3'
pacman -Qq "mpv" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nyt-dlp'
pacman -Qq "pipewire" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\npipewire-alsa\npipewire-pulse'
pacman -Qq "podman" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nslirp4netns\npodman-compose\nnetavark\naardvark-dns'
pacman -Qq "sway" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nxdg-desktop-portal-gtk\nxdg-desktop-portal-wlr\nxorg-xwayland'
pacman -Qq "system-config-printer" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ncups-pk-helper'
pacman -Qq "thunar" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ngvfs\nthunar-archive-plugin\nthunar-media-tags-plugin\nthunar-volman\ntumbler'
pacman -Qq "tlp" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nsmartmontools'
pacman -Qq "transmission-gtk" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ntransmission-cli'
if [[ -n "${DEPENDENCIES}" ]]; then
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if pacman -S --noprogressbar --noconfirm --needed --asdeps - <<<"${DEPENDENCIES}"; then
            break
        else
            log_warning "'pacman' failed. Retrying now."
        fi
    done
fi
## Reinstall packages as dependencies
DEPENDENCIES=""
pacman -Qq "blas-openblas" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nblas-openblas'
pacman -Qq "pipewire-jack" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\npipewire-jack'
pacman -Qq "tesseract-data-deu" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ntesseract-data-deu'
pacman -Qq "tesseract-data-eng" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ntesseract-data-eng'
pacman -Qq "tesseract-data-fra" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ntesseract-data-fra'
pacman -Qq "tesseract-data-nld" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ntesseract-data-nld'
if [[ -n "${DEPENDENCIES}" ]]; then
    for i in {1..5}; do
        if [[ "${i}" -eq 5 ]]; then
            log_err "Too many retries."
            exit 1
        fi
        if pacman -S --noprogressbar --noconfirm --asdeps - <<<"${DEPENDENCIES}"; then
            break
        else
            log_warning "'pacman' failed. Retrying now."
        fi
    done
fi

# Set up user scripts
## All users
FILES=(
    "dot-files.sh"
    "install.conf"
)
for user in "${USERS[@]}"; do
    [[ -n "${user}" ]] ||
        continue
    id "${user}" >/dev/null 2>&1 ||
        var_invalid_err_exit "${user}" "USERS"
    for tmp_file in "${FILES[@]}"; do
        file="${SCRIPT_DIR}"/"${tmp_file}"
        [[ -f "${file}" ]] ||
            var_invalid_err_exit "${file}" "FILES"
        cp "${file}" "$(eval echo ~"${user}")"/
        chown "${user}":"${user}" "$(eval echo ~"${user}")"/"${tmp_file}"
    done
    chmod 755 "$(eval echo ~"${user}")"/dot-files.sh
done
## SYSUSER
FILES=(
    "nix.conf"
    "pkgs-flatpak.txt"
    "pkgs-post.txt"
    "post.sh"
    "secureboot.sh"
)
for tmp_file in "${FILES[@]}"; do
    file="${SCRIPT_DIR}"/"${tmp_file}"
    [[ -f "${file}" ]] ||
        var_invalid_err_exit "${file}" "FILES"
    cp "${file}" "$(eval echo ~"${SYSUSER}")"/
    chown "${SYSUSER}":"${SYSUSER}" "$(eval echo ~"${SYSUSER}")"/"${tmp_file}"
done
chmod 755 "$(eval echo ~"${SYSUSER}")"/post.sh

# Configure /etc
## Configure /etc/crypttab
if lsblk -rno TYPE "${DISK1P2}" | grep -q "raid1"; then
    MD0UUID="$(blkid -s UUID -o value /dev/md/md0)"
else
    MD0UUID="$(blkid -s UUID -o value "${DISK1P2}")"
fi
echo "md0_crypt UUID=${MD0UUID} none luks,key-slot=0" >/etc/crypttab
## Configure /etc/localtime
ln -sf /usr/share/zoneinfo/"${TIMEZONE}" /etc/localtime
hwclock --systohc
## Configure /etc/vconsole.conf
echo "KEYMAP=${KEYMAP}" >/etc/vconsole.conf
## Configure /etc/hostname
echo "${HOSTNAME}" >/etc/hostname
## Configure /etc/hosts
{
    echo "127.0.0.1  localhost localhost.localdomain"
    echo "127.0.1.1  ${HOSTNAME}.${DOMAIN}	${HOSTNAME}"
    echo "::1  ip6-localhost ip6-localhost.localdomain ip6-loopback ip6-loopback.localdomain"
    echo "ff02::1  ip6-allnodes"
    echo "ff02::2  ip6-allrouters"
} >/etc/hosts
## Configure /etc/cryptboot.conf
### Clone cryptboot
if [[ "${IS_RELEASE}" == "true" ]]; then
    git clone -b "${CRYPTBOOT_VERSION}" https://github.com/leomeinel/cryptboot.git /git/cryptboot
else
    git clone -b main https://github.com/leomeinel/cryptboot.git /git/cryptboot
fi
### Modify /etc/cryptboot.conf
{
    echo ""
    echo "# arch-install"
    echo "ENABLE_OPROM=\"${ENABLE_OPROM}\""
} >>/git/cryptboot/cryptboot.conf
cp /git/cryptboot/cryptboot.conf /etc/
## Configure /etc/xdg/user-dirs.defaults
### START sed
FILE=/etc/xdg/user-dirs.defaults
STRING="^TEMPLATES="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s|${STRING}|#TEMPLATES=|g" "${FILE}"
STRING="^PUBLICSHARE="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s|${STRING}|#PUBLICSHARE=|g" "${FILE}"
STRING="^DESKTOP="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s|${STRING}|#DESKTOP=|g" "${FILE}"
STRING="^MUSIC="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s|${STRING}|#MUSIC=|g" "${FILE}"
STRING="^PICTURES="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s|${STRING}|#PICTURES=|g" "${FILE}"
STRING="^VIDEOS="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s|${STRING}|#VIDEOS=|g" "${FILE}"
### END sed
{
    echo ""
    echo "# arch-install"
    echo "TEMPLATES=Documents/Templates"
    echo "PUBLICSHARE=Documents/Public"
    echo "DESKTOP=Desktop"
    echo "MUSIC=Documents/Music"
    echo "PICTURES=Documents/Pictures"
    echo "VIDEOS=Documents/Videos"
} >>"${FILE}"
## Configure /etc/mdadm.conf.d/50-arch-install.conf
if lsblk -rno TYPE "${DISK1P2}" | grep -q "raid1"; then
    mkdir -p /etc/mdadm.conf.d/
    {
        mdadm -Ds
        echo "MAILADDR root"
    } >/etc/mdadm.conf.d/50-arch-install.conf
fi
## Configure /etc/usbguard/rules.conf
usbguard generate-policy >/etc/usbguard/rules.conf
usbguard add-user -g usbguard --devices=modify,list,listen --policy=list --exceptions=listen
## Configure /etc/usbguard/usbguard-daemon.conf
## START sed
FILE=/etc/usbguard/usbguard-daemon.conf
STRING="^PresentControllerPolicy="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s/${STRING}/#PresentControllerPolicy=/g" "${FILE}"
## END sed
{
    echo ""
    echo "# arch-install"
    echo "PresentControllerPolicy=apply-policy"
} >>"${FILE}"
## Configure /etc/pam.d/system-login
{
    echo ""
    echo "# arch-install"
    echo "auth optional pam_faildelay.so delay=8000000"
} >>/etc/pam.d/system-login
## Configure /etc/pam.d/su
{
    echo ""
    echo "# arch-install"
    echo "auth required pam_wheel.so use_uid"
} >>/etc/pam.d/su
## Configure /etc/pam.d/su-l
{
    echo ""
    echo "# arch-install"
    echo "auth required pam_wheel.so use_uid"
} >>/etc/pam.d/su-l
### START sed
## Configure /etc/security/faillock.conf
{
    echo ""
    echo "# arch-install"
    echo "dir = /var/lib/faillock"
} >>/etc/security/faillock.conf
## Configure /etc/audit/auditd.conf
### START sed
FILE=/etc/audit/auditd.conf
STRING="^log_group.*="
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s/${STRING}/#log_group =/g" "${FILE}"
### END sed
{
    echo ""
    echo "# arch-install"
    echo "log_group = audit"
} >>"${FILE}"
## Configure /etc/libvirt/network.conf
{
    echo ''
    echo '# arch-install'
    echo 'firewall_backend = "nftables"'
} >>/etc/libvirt/network.conf
## Configure /etc/nsswitch.conf
### START sed
FILE=/etc/nsswitch.conf
STRING="hosts: mymachines"
grep -q "${STRING}" "${FILE}" || sed_exit
sed -i "s/^${STRING}/#hosts: mymachines/g" "${FILE}"
### END sed
tmpfile="$(mktemp /tmp/arch-install-XXXXXX)"
cp "${FILE}" "${tmpfile}" &&
    {
        echo ""
        echo "# arch-install"
        grep "${STRING}" "${tmpfile}" | sed "s/^.*${STRING}/${STRING} mdns/g"
    } >>"${FILE}"
rm -f "${tmpfile}"
## Configure /etc/avahi/avahi-daemon.conf
{
    echo ""
    echo "# arch-install"
    echo "[server]"
    echo "domain-name=${DOMAIN}"
} >>/etc/avahi/avahi-daemon.conf
## Configure /etc/mdns.allow
{
    echo ".${DOMAIN}"
    echo ".local"
} >/etc/mdns.allow
## Configure /etc/snap-pac.ini
{
    echo ""
    echo "# arch-install"
    echo "[root]"
    echo "snapshot = True"
    echo 'important_packages = ["dracut", "linux", "linux-lts", "linux-zen"]'
    echo ""
    echo "[usr]"
    echo "snapshot = True"
    echo 'important_packages = ["dracut", "linux", "linux-lts", "linux-zen"]'
    echo ""
    echo "[var]"
    echo "snapshot = True"
    echo 'important_packages = ["dracut", "linux", "linux-lts", "linux-zen"]'
    echo ""
    echo "[var_lib]"
    echo "snapshot = True"
    echo 'important_packages = ["dracut", "linux", "linux-lts", "linux-zen"]'
    echo ""
    echo "[var_lib_mysql]"
    echo "snapshot = True"
    echo 'important_packages = ["dracut", "linux", "linux-lts", "linux-zen"]'
} >>/etc/snap-pac.ini
## Configure /etc/dracut.conf.d/cmdline.conf
LV0_UUID="$(blkid -s UUID -o value /dev/mapper/vg0-lv0)"
PARAMETERS="rd.auto rd.luks.uuid=${MD0UUID} rd.luks rd.lvm rd.md root=UUID=${LV0_UUID} rootfstype=btrfs rootflags=rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvol=/@ rd.vconsole.unicode rd.vconsole.keymap=${KEYMAP} loglevel=3 bgrt_disable audit=1 audit_backlog_limit=8192 lsm=landlock,lockdown,yama,integrity,apparmor,bpf iommu=pt zswap.enabled=0 lockdown=integrity module.sig_enforce=1"
### If on intel set kernel parameter intel_iommu=on
pacman -Qq "intel-ucode" >/dev/null 2>&1 &&
    PARAMETERS="${PARAMETERS} intel_iommu=on"
echo "kernel_cmdline=\"${PARAMETERS}\"" >/etc/dracut.conf.d/50-arch-install-cmdline.conf
## Harden system
### Disable coredump and set process limit
{
    echo ""
    echo "# arch-install"
    echo "* hard core 0"
    echo "* soft nproc 10000"
    echo "* hard nproc 20000"
} >>/etc/security/limits.conf
### Harden Postfix
{
    echo ""
    echo "# arch-install"
    echo "myhostname = localhost"
    echo "mydomain = localdomain"
    # shellcheck disable=SC2016
    echo 'mydestination = $myhostname, localhost.$mydomain, localhost'
    # shellcheck disable=SC2016
    echo 'inet_interfaces = $myhostname, localhost'
    echo "mynetworks_style = host"
    echo "default_transport = error: outside mail is not deliverable"
    echo "disable_vrfy_command = yes"
} >>/etc/postfix/main.cf

# Configure /usr
## Set up /usr/local/bin
cp /git/cryptboot/cryptboot /usr/local/bin/
cp /git/cryptboot/cryptboot-efikeys /usr/local/bin/
## Set up /usr/local/bin/upgrade-home
UPGRADE_HOME="$(
    cat <<'EOF'
#!/usr/bin/env bash
###
# File: upgrade-home
# Author: Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID: MIT
# URL: https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

log_err() {
    /usr/bin/logger -s -p local0.err <<<"$(basename "${0}"): ${*}"
}

# If current user is not UID 1000, don't do anything
if [[ "${UID}" -ne 1000 ]]; then
    log_err "You can only run this script as UID 1000."
    exit 1
fi

# Run ~/.config/dot-files/update.sh for each user
EOF
)"
UPGRADE_HOME+=$'\n/usr/bin/doas /usr/bin/systemd-run -P --wait --system -E HOME=/root -M root@ /bin/sh -c '"'"'. /etc/profile && . ~/.bash_profile && cd ~/.config/dot-files && /usr/bin/git pull --no-gpg-sign --no-edit && /usr/bin/chmod +x ~/.config/dot-files/update.sh && /usr/bin/git add . && { /usr/bin/git commit --no-gpg-sign -m "Prepare files for update" || true; } && ~/.config/dot-files/update.sh'"'"''
UPGRADE_HOME+=$'\n/bin/sh -c '"'"'. /etc/profile && . ~/.bash_profile && cd ~/.config/dot-files && /usr/bin/git pull --no-gpg-sign --no-edit && /usr/bin/chmod +x ~/.config/dot-files/update.sh && /usr/bin/git add . && { /usr/bin/git commit --no-gpg-sign -m "Prepare files for update" || true; } && ~/.config/dot-files/update.sh'"'"''
TMP_USERS=(
    "${GUESTUSER}"
    "${HOMEUSER}"
    "${VIRTUSER}"
    "${WORKUSER}"
)
for user in "${TMP_USERS[@]}"; do
    [[ -n "${user}" ]] ||
        continue
    id "${user}" >/dev/null 2>&1 ||
        var_invalid_err_exit "${user}" "TMP_USERS"
    UPGRADE_HOME+=$'\n/usr/bin/doas /usr/bin/systemd-run -P --wait --user -M '"${user}"'@ /bin/sh -c '"'"'. /etc/profile && . ~/.bash_profile && cd ~/.config/dot-files && /usr/bin/git pull --no-gpg-sign --no-edit && /usr/bin/chmod +x ~/.config/dot-files/update.sh && /usr/bin/git add . &&{ /usr/bin/git commit --no-gpg-sign -m "Prepare files for update" || true; } && ~/.config/dot-files/update.sh'"'"''
done
echo "${UPGRADE_HOME}" >/usr/local/bin/upgrade-home
## Configure snapper
### START sed
STRING0="^ALLOW_GROUPS="
STRING1="^SPACE_LIMIT="
STRING2="^FREE_LIMIT="
STRING3="^NUMBER_LIMIT="
STRING4="^NUMBER_LIMIT_IMPORTANT="
STRING5="^TIMELINE_CLEANUP="
STRING6="^TIMELINE_LIMIT_MONTHLY="
STRING7="^TIMELINE_LIMIT_YEARLY="
STRING8="^TIMELINE_CREATE="
STRING9="^TIMELINE_LIMIT_HOURLY="
STRING10="^TIMELINE_LIMIT_DAILY="
STRING11="^TIMELINE_LIMIT_WEEKLY="
FILE0=/usr/share/snapper/config-templates/default
grep -q "${STRING0}" "${FILE0}" || sed_exit
sed -i "s/${STRING0}/#ALLOW_GROUPS=/g" "${FILE0}"
grep -q "${STRING1}" "${FILE0}" || sed_exit
sed -i "s/${STRING1}/#SPACE_LIMIT=/g" "${FILE0}"
grep -q "${STRING2}" "${FILE0}" || sed_exit
sed -i "s/${STRING2}/#FREE_LIMIT=/g" "${FILE0}"
grep -q "${STRING3}" "${FILE0}" || sed_exit
sed -i "s/${STRING3}/#NUMBER_LIMIT=/g" "${FILE0}"
grep -q "${STRING4}" "${FILE0}" || sed_exit
sed -i "s/${STRING4}/#NUMBER_LIMIT_IMPORTANT=/g" "${FILE0}"
grep -q "${STRING5}" "${FILE0}" || sed_exit
sed -i "s/${STRING5}/#TIMELINE_CLEANUP=/g" "${FILE0}"
grep -q "${STRING6}" "${FILE0}" || sed_exit
sed -i "s/${STRING6}/#TIMELINE_LIMIT_MONTHLY=/g" "${FILE0}"
grep -q "${STRING7}" "${FILE0}" || sed_exit
sed -i "s/${STRING7}/#TIMELINE_LIMIT_YEARLY=/g" "${FILE0}"
grep -q "${STRING8}" "${FILE0}" || sed_exit
sed -i "s/${STRING8}/#TIMELINE_CREATE=/g" "${FILE0}"
grep -q "${STRING9}" "${FILE0}" || sed_exit
sed -i "s/${STRING9}/#TIMELINE_LIMIT_HOURLY=/g" "${FILE0}"
grep -q "${STRING10}" "${FILE0}" || sed_exit
sed -i "s/${STRING10}/#TIMELINE_LIMIT_DAILY=/g" "${FILE0}"
grep -q "${STRING11}" "${FILE0}" || sed_exit
sed -i "s/${STRING11}/#TIMELINE_LIMIT_WEEKLY=/g" "${FILE0}"
### END sed
{
    echo ""
    echo "# arch-install"
    echo 'ALLOW_GROUPS="wheel"'
    echo 'SPACE_LIMIT="0.2"'
    echo 'FREE_LIMIT="0.4"'
    echo 'NUMBER_LIMIT="5"'
    echo 'NUMBER_LIMIT_IMPORTANT="5"'
    echo 'TIMELINE_CLEANUP="yes"'
    echo 'TIMELINE_LIMIT_MONTHLY="0"'
    echo 'TIMELINE_LIMIT_YEARLY="0"'
} >>"${FILE0}"
### Remove & unmount snapshots (Prepare snapshot dirs 1)
for dir in "${SUBVOLUMES[@]}"; do
    [[ -d "${dir}" ]] ||
        {
            var_invalid_warning "${dir}" "SUBVOLUMES"
            continue
        }
    umount "${dir}".snapshots
    rm -rf "${dir}".snapshots
done
### Append configs individually
SUBVOLUMES_LENGTH="${#SUBVOLUMES[@]}"
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    #### Copy template
    FILE1=/usr/share/snapper/config-templates/"${CONFIGS[${i}]}"
    cp "${FILE0}" "${FILE1}"
    #### Set variables for configs
    case "${CONFIGS[${i}]}" in
    "root" | "usr" | "var" | "var_lib" | "var_lib_containers" | "var_lib_flatpak" | "var_lib_mysql")
        {
            echo 'TIMELINE_CREATE="yes"'
            echo 'TIMELINE_LIMIT_HOURLY="2"'
            echo 'TIMELINE_LIMIT_DAILY="1"'
            echo 'TIMELINE_LIMIT_WEEKLY="0"'
        } >>"${FILE1}"
        ;;
    "var_lib_libvirt")
        {
            echo 'TIMELINE_CREATE="yes"'
            echo 'TIMELINE_LIMIT_HOURLY="0"'
            echo 'TIMELINE_LIMIT_DAILY="1"'
            echo 'TIMELINE_LIMIT_WEEKLY="0"'
        } >>"${FILE1}"
        ;;
    "var_log")
        {
            echo 'TIMELINE_CREATE="yes"'
            echo 'TIMELINE_LIMIT_HOURLY="1"'
            echo 'TIMELINE_LIMIT_DAILY="1"'
            echo 'TIMELINE_LIMIT_WEEKLY="1"'
        } >>"${FILE1}"
        ;;
    "home")
        {
            echo 'TIMELINE_CREATE="yes"'
            echo 'TIMELINE_LIMIT_HOURLY="2"'
            echo 'TIMELINE_LIMIT_DAILY="2"'
            echo 'TIMELINE_LIMIT_WEEKLY="0"'
        } >>"${FILE1}"
        ;;
    *)
        {
            echo 'TIMELINE_CREATE="no"'
            echo 'TIMELINE_LIMIT_HOURLY="0"'
            echo 'TIMELINE_LIMIT_DAILY="0"'
            echo 'TIMELINE_LIMIT_WEEKLY="0"'
        } >>"${FILE1}"
        ;;
    esac
    #### Create config
    snapper --no-dbus -c "${CONFIGS[${i}]}" create-config -t "${CONFIGS[${i}]}" "${SUBVOLUMES[${i}]}"
done
### Replace subvolumes for snapshots (Prepare snapshot dirs 2)
for dir in "${SUBVOLUMES[@]}"; do
    [[ -d "${dir}" ]] ||
        var_invalid_err_exit "${dir}" "SUBVOLUMES"
    btrfs subvolume delete "${dir}".snapshots
    mkdir -p "${dir}".snapshots
done
### Mount /etc/fstab
mount -a
### Set correct permissions on snapshots (Prepare snapshot dirs 3)
for dir in "${SUBVOLUMES[@]}"; do
    [[ -d "${dir}" ]] ||
        var_invalid_err_exit "${dir}" "SUBVOLUMES"
    chown :wheel "${dir}".snapshots
done

# Create dirs/files and modify perms
FILES_600=(
    /etc/audit/rules.d/50-arch-install.rules
    /etc/ssh/sshd_config.d/50-arch-install.conf
)
DIRS_700=(
    /etc/access/keys
    /etc/audit/rules.d
    /etc/encryption/keys
    /etc/ssh/sshd_config.d
    /root/backup
)
FILES_755=(
    /usr/local/bin/amberol
    /usr/local/bin/ark
    /usr/local/bin/calibre
    /usr/local/bin/chromium
    /usr/local/bin/cryptboot
    /usr/local/bin/cryptboot-efikeys
    /usr/local/bin/floorp
    /usr/local/bin/freetube
    /usr/local/bin/kdenlive
    /usr/local/bin/kicad
    /usr/local/bin/librewolf
    /usr/local/bin/nextcloud
    /usr/local/bin/nitrokey-app
    /usr/local/bin/obs
    /usr/local/bin/pwvucontrol
    /usr/local/bin/rpi-imager
    /usr/local/bin/sweethome3d
    /usr/local/bin/tagger
    /usr/local/bin/upgrade-home
    /usr/local/bin/upgrade-packages
)
for file in "${FILES_600[@]}"; do
    ! [[ -f "${file}" ]] &&
        touch "${file}"
    chmod 600 "${file}"
done
for file in "${FILES_755[@]}"; do
    ! [[ -f "${file}" ]] &&
        touch "${file}"
    chmod 755 "${file}"
done
for dir in "${DIRS_700[@]}"; do
    ! [[ -d "${dir}" ]] &&
        mkdir -p "${dir}"
    chmod 700 "${dir}"
done

# Enable systemd services
pacman -Qq "apparmor" >/dev/null 2>&1 &&
    systemctl enable apparmor.service
pacman -Qq "audit" >/dev/null 2>&1 &&
    systemctl enable auditd.service
pacman -Qq "avahi" >/dev/null 2>&1 &&
    systemctl enable avahi-daemon.service
pacman -Qq "bluez" >/dev/null 2>&1 &&
    systemctl enable bluetooth.service
pacman -Qq "containerd" >/dev/null 2>&1 &&
    systemctl enable containerd.service
pacman -Qq "cups" >/dev/null 2>&1 &&
    systemctl enable cups.service
if pacman -Qq "libvirt" >/dev/null 2>&1; then
    systemctl enable libvirtd.socket
    systemctl enable virtlogd.socket
fi
pacman -Qq "logwatch" >/dev/null 2>&1 &&
    systemctl enable logwatch.timer
pacman -Qq "networkmanager" >/dev/null 2>&1 &&
    systemctl enable NetworkManager.service
if pacman -Qq "open-vm-tools" >/dev/null 2>&1; then
    systemctl enable vmtoolsd.service
    systemctl enable vmware-vmblock-fuse.service
fi
pacman -Qq "podman" >/dev/null 2>&1 &&
    systemctl enable podman.service
if pacman -Qq "reflector" >/dev/null 2>&1; then
    systemctl enable reflector.service
    systemctl enable reflector.timer
fi
if pacman -Qq "snapper" >/dev/null 2>&1; then
    systemctl enable snapper-cleanup.timer
    systemctl enable snapper-timeline.timer
fi
pacman -Qq "sysstat" >/dev/null 2>&1 &&
    systemctl enable sysstat.service
pacman -Qq "systemd" >/dev/null 2>&1 &&
    systemctl enable systemd-resolved.service
pacman -Qq "tlp-rdw" >/dev/null 2>&1 && pacman -Qq "networkmanager" >/dev/null 2>&1 &&
    systemctl enable NetworkManager-dispatcher.service
if pacman -Qq "tlp" >/dev/null 2>&1; then
    systemctl enable tlp.service
    if pacman -Qq "systemd" >/dev/null 2>&1; then
        systemctl mask systemd-rfkill.service
        systemctl mask systemd-rfkill.socket
    fi
fi
pacman -Qq "usbguard" >/dev/null 2>&1 &&
    systemctl enable usbguard.service
pacman -Qq "util-linux" >/dev/null 2>&1 &&
    systemctl enable fstrim.timer

# Enable sshd.service and add SYSUSER_PUBKEY if enabled
if [[ -n "${SYSUSER_PUBKEY}" ]] && pacman -Qq "openssh" >/dev/null 2>&1; then
    systemctl enable sshd.service
    runuser -l "${SYSUSER}" -c "mkdir -p ~/.ssh && chmod 700 ~/.ssh && echo ${SYSUSER_PUBKEY} >~/.ssh/authorized_keys"
fi

# Set up /efi
bootctl --esp-path=/efi --no-variables install
dracut --regenerate-all --force

# Remove repo
rm -rf /git

# Notify user if script has finished successfully
echo "'$(basename "${0}")' has finished successfully."
