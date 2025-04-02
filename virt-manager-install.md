# Enable UEFI and secure boot

Choose `Customize configuration before install`.

Choose `Q35` as Chipset and `UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd` as Firmware.

# Use virtio for video

Enable `Edit -> Preferences -> General -> Enable XML editing`.

Go to `Video [...]` and replace content of `XML` tab with the following:

```xml
<video>
  <model type="virtio" heads="1" primary="yes"/>
</video>
```
