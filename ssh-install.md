# Using ssh to authenticate in the installation image

Follow [this guide](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) for up to date instructions.

It should be enough to just use the following script to set a password for root

```sh
passwd
```

# Using ssh for Post-installation

Set `ENABLE_SSH="true"` and modify `SYSUSER_PUBKEY` in `install.conf` before running `prepare.sh`.

After rebooting, you will have to enter the decryption key for your disk. This cannot be done over ssh.

You will then be able to log into the target system via ssh from another machine in the same local network. To do this run the following script.

```sh
# <ip_address> might have changed. Execute ip a on target system if the old <ip_address> doesn't work
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9122 -i ~/.ssh/<private_key> <SYSUSER>@<ip_address>
```
