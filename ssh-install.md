# Using ssh to authenticate in the installation image

:information_source: | Follow [this guide](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) for up to date instructions.

It should be enough to just use the following script to set a password for root:

```sh
passwd
```

# Using ssh for Post-installation

:information_source: | After rebooting, you will have to enter the decryption key for your disk. This cannot be done over ssh.

:information_source: | Due to security restrictions, you will only be able to ssh into the target system from a local network.

Set `ENABLE_SSH="true"` and modify `SYSUSER_PUBKEY` in `install.conf` before running `prepare.sh`.

To do this run the following script:

```sh
# <ip_address> might have changed. Execute ip a on target system if the old <ip_address> doesn't work
ssh -o StrictHostKeyChecking=no -o UserKnownHostsFile=/dev/null -p 9122 -i ~/.ssh/<private_key> <SYSUSER>@<ip_address>
```
