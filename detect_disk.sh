#!/bin/bash

blkid -t LABEL="any:md0" -s PARTUUID -o value
blkid -t LABEL="BOOT" -s PARTUUID -o value
{
  echo "DISK1P1=\"\$(blkid -t LABEL=\"BOOT\" -s PARTUUID -o value | sed -n '1p' | tr -d \"[:space:]\")"
  echo "DISK1P2=\"\$(blkid -t LABEL=\"any:md0\" -s PARTUUID -o value | sed -n '1p' | tr -d \"[:space:]\")"
  echo "DISK2P1=\"\$(blkid -t LABEL=\"BOOT\" -s PARTUUID -o value | sed -n '1p' | tr -d \"[:space:]\")"
  echo "DISK2P1=\"\$(blkid -t LABEL=\"any:md0\" -s PARTUUID -o value | sed -n '2p' | tr -d \"[:space:]\")"
} >> /etc/environment
mount PARTUUID=$DISK1P1 /mnt
mount PARTUUID=$DISK2P1 /mnt
