# Using ssh to authenticate in the installation image

Follow [this guide](https://wiki.archlinux.org/title/Install_Arch_Linux_via_SSH) for up to date instructions.

It should be enough to just use the following script to set a password for root

```sh
passwd
```

# Using ssh for Post-installation

Set `ENABLE_SSH="true"` in `install.conf` before running `/git/arch-install/setup.sh`.

After running `/git/arch-install/setup.sh`, you will have to add your public key to the SYSUSER account.

The following script is a way to do this after `setup.sh` has finished successfully. Text written as `<...>` will have to be replaced according to your configuration.

```sh
su <SYSUSER>
# A public key looks similar to this: ssh-ed25519 AAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAA
mkdir -p ~/.ssh
chmod 700 ~/.ssh
echo "<public_key>" >~/.ssh/authorized_keys
exit
```

After rebooting, you will have to enter the decryption key for your disk. This cannot be done over ssh.

You will then be able to log into the target system via ssh from another machine in the same local network. To do this run the following script.

```sh
# <ip_address> might have changed. Execute ip a on target system if the old <ip_address> doesn't work
ssh -p 9122 -i ~/.ssh/<private_key> <SYSUSER>@<ip_address>
```
