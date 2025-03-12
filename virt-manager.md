Choose `Customize configuration before install`.

Choose `Q35` as Chipset and `UEFI x86_64: /usr/share/edk2/x64/OVMF_CODE.secboot.4m.fd` as Firmware.

Enable `Edit -> Preferences -> General -> Enable XML editing`.

Go to `Video <...>` and replace content of `XML` tab with the following:

```
<video>
    <model type="qxl" ram="65536" vram="65536" vgamem="16384" heads="1"/>
</video>
```
