#!/bin/sh

/usr/bin/rsync -a --delete /.boot.bak/* /.boot.bak.old/
/usr/bin/rsync -a --delete /boot/* /.boot.bak/
/usr/bin/umount /boot
/usr/bin/mount PARTUUID="$DISK2P1_PARTUUID" /boot/
/usr/bin/rsync -a --delete /.boot.bak/* /boot/
/usr/bin/umount /boot
/usr/bin/mount PARTUUID="$DISK1P1_PARTUUID" /boot
