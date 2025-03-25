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

# Source config
SCRIPT_DIR="$(dirname -- "$(readlink -f -- "${0}")")"
# shellcheck source=/dev/null
. "${SCRIPT_DIR}"/install.conf

# Fail on error
set -e

# Define functions
sed_exit() {
    echo "ERROR: 'sed' didn't replace, report this @"
    echo "       https://github.com/leomeinel/arch-install/issues"
    exit 1
}

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
useradd -ms /bin/bash -G video "${GUESTUSER}"
useradd -ms /bin/bash -G video "${HOMEUSER}"
useradd -ms /bin/bash -G adm,audit,log,proc,rfkill,sys,systemd-journal,usbguard,wheel,video "${SYSUSER}"
useradd -ms /bin/bash -G libvirt,video "${VIRTUSER}"
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
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    echo "Enter password for ${GUESTUSER}"
    passwd "${GUESTUSER}" && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    echo "Enter password for ${HOMEUSER}"
    passwd "${HOMEUSER}" && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    echo "Enter password for root"
    passwd root && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    echo "Enter password for ${SYSUSER}"
    passwd "${SYSUSER}" && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    echo "Enter password for ${VIRTUSER}"
    passwd "${VIRTUSER}" && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    echo "Enter password for ${WORKUSER}"
    passwd "${WORKUSER}" && break ||
        echo "WARNING: You have entered an incorrect password. Retrying now."
done

# Configure /etc before installing packages
## Configure locale
FILE=/etc/locale.gen
{
    echo ""
    echo "# arch-install"
} >>"${FILE}"
for string in "${LANGUAGES[@]}"; do
    echo "${string}" >>"${FILE}"
done
locale-gen
## Configure /etc/doas.conf
chown root:root /etc/doas.conf
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
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    pacman -Syu --noprogressbar --noconfirm --needed - <"${SCRIPT_DIR}/pkgs-setup.txt" && break ||
        echo "WARNING: pacman failed. Retrying now."
done
## Install optional dependencies
DEPENDENCIES=""
pacman -Qq "apparmor" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\npython-notify2\npython-psutil'
pacman -Qq "kdenlive" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nmediainfo'
pacman -Qq "libvirt" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ndnsmasq'
pacman -Qq "lollypop" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ngst-plugins-base\ngst-plugins-good\ngst-libav\nkid3-common'
pacman -Qq "mpv" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nyt-dlp'
pacman -Qq "pipewire" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\npipewire-alsa\npipewire-pulse'
pacman -Qq "podman" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nslirp4netns\npodman-compose\nnetavark\naardvark-dns'
pacman -Qq "sway" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nxdg-desktop-portal-gtk\nxdg-desktop-portal-wlr'
pacman -Qq "system-config-printer" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ncups-pk-helper'
pacman -Qq "thunar" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ngvfs\nthunar-archive-plugin\nthunar-media-tags-plugin\nthunar-volman\ntumbler'
pacman -Qq "tlp" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nsmartmontools'
pacman -Qq "transmission-gtk" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\ntransmission-cli'
pacman -Qq "wlroots" >/dev/null 2>&1 &&
    DEPENDENCIES+=$'\nxorg-xwayland'
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    pacman -S --noprogressbar --noconfirm --needed --asdeps - <<<"${DEPENDENCIES}" && break ||
        echo "WARNING: pacman failed. Retrying now."
done
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
for i in {1..5}; do
    [[ "${i}" -eq 5 ]] &&
        {
            echo "ERROR: Too many retries. Exiting now."
            exit 1
        }
    pacman -S --noprogressbar --noconfirm --asdeps - <<<"${DEPENDENCIES}" && break ||
        echo "WARNING: pacman failed. Retrying now."
done

# Set up user scripts
## All users
FILES=("dot-files.sh" "install.conf")
USERS=("${GUESTUSER}" "${HOMEUSER}" "root" "${SYSUSER}" "${VIRTUSER}" "${WORKUSER}")
for user in "${USERS[@]}"; do
    for file in "${FILES[@]}"; do
        cp "${SCRIPT_DIR}"/"${file}" "$(eval echo ~"${user}")"/
        chown "${user}":"${user}" "$(eval echo ~"${user}")"/"${file}"
    done
    chmod 755 "$(eval echo ~"${user}")"/dot-files.sh
done
## SYSUSER
FILES=("nix.conf" "pkgs-flatpak.txt" "post.sh" "secureboot.sh")
for file in "${FILES[@]}"; do
    cp "${SCRIPT_DIR}"/"${file}" "$(eval echo ~"${SYSUSER}")"/
    chown "${SYSUSER}":"${SYSUSER}" "$(eval echo ~"${SYSUSER}")"/"${file}"
done
chmod 755 "$(eval echo ~"${SYSUSER}")"/post.sh

# Configure /etc
## Configure /etc/crypttab
if lsblk -rno TYPE "${DISK1P2}" | grep -q "raid1"; then
    MD0UUID="$(blkid -s UUID -o value /dev/md/md0)"
else
    MD0UUID="$(blkid -s UUID -o value "${DISK1P2}")"
fi
{
    echo "md0_crypt UUID=${MD0UUID} none luks,key-slot=0"
} >/etc/crypttab
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
DISK1P2UUID="$(blkid -s UUID -o value "${DISK1P2}")"
PARAMETERS="rd.luks.uuid=luks-${MD0UUID} rd.lvm.lv=vg0/lv0 rd.md.uuid=${DISK1P2UUID} root=/dev/mapper/vg0-lv0 rootfstype=btrfs rootflags=rw,noatime,compress=zstd:3,ssd,discard=async,space_cache=v2,subvolid=256,subvol=/@ rd.lvm.lv=vg0/lv1 rd.lvm.lv=vg0/lv2 rd.lvm.lv=vg0/lv3 rd.vconsole.unicode rd.vconsole.keymap=${KEYMAP} loglevel=3 bgrt_disable audit=1 audit_backlog_limit=8192 lsm=landlock,lockdown,yama,integrity,apparmor,bpf iommu=pt zswap.enabled=0 lockdown=integrity module.sig_enforce=1"
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
USERS=("${GUESTUSER}" "${HOMEUSER}" "${VIRTUSER}" "${WORKUSER}")
UPGRADE_HOME="$(
    cat <<'EOF'
#!/usr/bin/env bash
###
# File = upgrade-home
# Author = Leopold Meinel (leo@meinel.dev)
# -----
# Copyright (c) 2025 Leopold Meinel & contributors
# SPDX ID = MIT
# URL = https://opensource.org/licenses/MIT
# -----
###

# Fail on error
set -e

# If current user is not UID 1000, don't do anything
if [[ "${UID}" -ne 1000 ]]; then
    /usr/bin/echo "ERROR: You can only run this script as UID 1000"
    exit 1
fi

# Run ~/.config/dot-files/update.sh for each user
EOF
)"
for user in "${USERS[@]}"; do
    UPGRADE_HOME+=$'\n/usr/bin/doas /usr/bin/systemd-run -P --wait --user -M '"${user}"'@ /bin/bash -c '"'"'. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && cd ~/.config/dot-files && /usr/bin/git pull && /usr/bin/chmod +x ~/.config/dot-files/update.sh && ~/.config/dot-files/update.sh'"'"''
done
UPGRADE_HOME+=$'\n/usr/bin/doas /usr/bin/systemd-run -P --wait --system -E HOME=/root -M root@ /bin/bash -c '"'"'. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && cd ~/.config/dot-files && /usr/bin/git pull && /usr/bin/chmod +x ~/.config/dot-files/update.sh && ~/.config/dot-files/update.sh'"'"''
UPGRADE_HOME+=$'\nexec /bin/bash -c '"'"'. /nix/var/nix/profiles/default/etc/profile.d/nix-daemon.sh && cd ~/.config/dot-files && /usr/bin/git pull && /usr/bin/chmod +x ~/.config/dot-files/update.sh && ~/.config/dot-files/update.sh'"'"''
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
for subvolume in "${SUBVOLUMES[@]}"; do
    umount "${subvolume}".snapshots
    rm -rf "${subvolume}".snapshots
done
### Append configs individually
SUBVOLUMES_LENGTH="${#SUBVOLUMES[@]}"
[[ "${SUBVOLUMES_LENGTH}" -ne "${#CONFIGS[@]}" ]] &&
    {
        echo "ERROR: SUBVOLUMES and CONFIGS aren't the same length!"
        exit 1
    }
for ((i = 0; i < SUBVOLUMES_LENGTH; i++)); do
    #### Copy template
    FILE1="/usr/share/snapper/config-templates/${CONFIGS[${i}]}"
    cp "${FILE0}" "${FILE1}"
    #### Set variables for configs
    case "${CONFIGS[${i}]}" in
    "root" | "usr" | "nix" | "var" | "var_lib" | "var_lib_containers" | "var_lib_flatpak" | "var_lib_mysql")
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
for subvolume in "${SUBVOLUMES[@]}"; do
    btrfs subvolume delete "${subvolume}".snapshots
    mkdir -p "${subvolume}".snapshots
done
### Mount /etc/fstab
mount -a
### Set correct permissions on snapshots (Prepare snapshot dirs 3)
for subvolume in "${SUBVOLUMES[@]}"; do
    chown :wheel "${subvolume}".snapshots
done

# Create dirs/files and modify perms
FILES_600=("/etc/ssh/sshd_config.d/50-arch-install.conf" "/etc/audit/rules.d/50-arch-install.rules")
DIRS_700=("/etc/audit/rules.d" "/etc/ssh/sshd_config.d" "/etc/encryption/keys" "/etc/access/keys" "/root/backup")
FILES_755=("/etc/profile.d/zz-arch-install.sh" "/usr/local/bin/cryptboot" "/usr/local/bin/cryptboot-efikeys" "/usr/local/bin/floorp" "/usr/local/bin/freetube" "/usr/local/bin/librewolf" "/usr/local/bin/nitrokey-app" "/usr/local/bin/pwvucontrol" "/usr/local/bin/rpi-imager" "/usr/local/bin/sweethome3d" "/usr/local/bin/upgrade-home" "/usr/local/bin/upgrade-packages")
for file in "${FILES_600[@]}"; do
    [[ ! -f "${file}" ]] &&
        touch "${file}"
    chmod 600 "${file}"
done
for file in "${FILES_755[@]}"; do
    [[ ! -f "${file}" ]] &&
        touch "${file}"
    chmod 755 "${file}"
done
for dir in "${DIRS_700[@]}"; do
    [[ ! -f "${dir}" ]] &&
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
pacman -Qq "cups" >/dev/null 2>&1 &&
    systemctl enable cups.service
pacman -Qq "libvirt" >/dev/null 2>&1 &&
    {
        systemctl enable libvirtd.socket
        systemctl enable virtlogd.socket
    }
pacman -Qq "logwatch" >/dev/null 2>&1 &&
    systemctl enable logwatch.timer
pacman -Qq "networkmanager" >/dev/null 2>&1 &&
    systemctl enable NetworkManager.service
pacman -Qq "reflector" >/dev/null 2>&1 &&
    {
        systemctl enable reflector.service
        systemctl enable reflector.timer
    }
pacman -Qq "snapper" >/dev/null 2>&1 &&
    {
        systemctl enable snapper-cleanup.timer
        systemctl enable snapper-timeline.timer
    }
pacman -Qq "sysstat" >/dev/null 2>&1 &&
    systemctl enable sysstat.service
pacman -Qq "systemd" >/dev/null 2>&1 &&
    {
        systemctl enable systemd-resolved.service
        systemctl enable systemd-boot-update.service
    }
pacman -Qq "tlp-rdw" >/dev/null 2>&1 && pacman -Qq "networkmanager" >/dev/null 2>&1 &&
    systemctl enable NetworkManager-dispatcher.service
pacman -Qq "tlp" >/dev/null 2>&1 &&
    {
        systemctl enable tlp.service
        pacman -Qq "systemd" >/dev/null 2>&1 &&
            {
                systemctl mask systemd-rfkill.service
                systemctl mask systemd-rfkill.socket
            }
    }
pacman -Qq "usbguard" >/dev/null 2>&1 &&
    systemctl enable usbguard.service
pacman -Qq "util-linux" >/dev/null 2>&1 &&
    systemctl enable fstrim.timer
[[ "${ENABLE_SSH}" == "true" ]] && pacman -Qq "openssh" >/dev/null 2>&1 &&
    systemctl enable sshd.service

# Set up /boot & /efi
bootctl --esp-path=/efi --no-variables install
dracut --regenerate-all --force

# Remove repo
rm -rf /git

# Notify user if script has finished successfully
echo "INFO: $(basename "${0}") has finished successfully."
