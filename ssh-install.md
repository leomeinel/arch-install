# Using ssh in the installation image

:information_source: | Follow [this guide](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) for up to date instructions.

Set a password for root on the target system:

```sh
passwd
```

To ssh into the target system run:

```sh
# Execute ip a on the target system to get [ip_address]
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null root@[ip_address]
```

# Using ssh for Post-installation

:information_source: | After rebooting, you will have to enter the decryption key for your disk. This cannot be done over ssh.

:information_source: | Due to security restrictions, you will only be able to ssh into the target system from a local network.

Add your public ssh key to `SYSUSER_PUBKEY` in `install.conf` before running `prepare.sh`.

To ssh into the target system run:

```sh
# Execute ip a on the target system to get [ip_address]
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9122 -i ~/.ssh/[private_key] [SYSUSER]@[ip_address]
```
