# Talos for Orange Pi 5

[![Build Talos Linux for Orange Pi 5](https://github.com/si0ls/talos-orangepi5/actions/workflows/main.yaml/badge.svg)](https://github.com/si0ls/talos-orangepi5/actions/workflows/main.yaml)

This repository provides Talos Linux support for the Orange Pi 5 and Orange Pi 5 Plus.

## Upstream dependencies

This repo uses upstream dependencies that are not in sync with the last Talos version.

- kernel: [v6.1](https://github.com/armbian/linux-rockchip/tree/rk-6.1-rkr1) (based on BSP, maintained by [Armbian](https://www.armbian.com/) on `rk-6.1-rkr1` branch)
- talos: [v1.7.5](https://github.com/siderolabs/talos/tree/v1.7.5)

The best effort is made to keep the overlay in sync with the upstream dependencies.
This repository will be updated as soon as the new versions are available.

## Install

In order to flash the bootloader or the Talos Linux for Orange Pi 5 image, you need a current working system.

You can flash the drive from another computer (if you have the necessary adapters) or from the Orange Pi 5 itself with an [official distribution](http://www.orangepi.org/html/hardWare/computerAndMicrocontrollers/service-and-support/Orange-pi-5.html) provided by Orange Pi (or [Armbian](https://www.armbian.com/orangepi-5/)) for example.

It's made to be booted with EDK2 UEFI firmware built for Orange Pi 5.

### Install EDK2 bootloader

This repository provides images that **does not include a bootloader**, so you need to handle this step yourself.

You must flash the [EDK2 UEFI firmware for Rockchip RK3588 platforms](https://github.com/edk2-porting/edk2-rk3588) on the SPI flash of the Orange Pi 5.

As this repository is based on the same kernel version as the one used by edk2-rk3588, the device tree overlays provided in the EDK2 firmware should work with the kernel provided here.

### Install Talos Linux

#### Install on a drive

The Talos image can be flashed on an SD card, a NVMe drive, or a SATA drive.

You can download the latest image from the [releases page](https://github.com/si0ls/talos-orangepi5/releases).

The image can be flashed using [Etcher](https://www.balena.io/etcher/) on Windows, macOS, or Linux or using `dd` on Linux:

```bash
# Extract the image for the variant you want to flash
xz -d talos-orangepi5.raw.xz

# Flash the image
# Replace /dev/sdX with the device of the SD card, NVMe drive, or SATA drive
# You can find the device with `lsblk` or `fdisk -l`
dd if=talos-orangepi5.raw of=/dev/sdX bs=4M status=progress
```

The image should boot with UEFI (edk2-rk3588).

#### PXE Boot

You can setup PXE boot with edk2-rk3588.

**This repository does not provide a PXE server**, it is up to you to set up the PXE server.

The [releases](https://github.com/si0ls/talos-orangepi5/releases) provides the following files needed for PXE boot:

- `kernel-arm64` (the kernel)
- `initramfs-metal-arm64.xz` (the initramfs)
- `rk3588s-orangepi-5.dtb` and `rk3588-orangepi-5-plus.dtb` (the device tree blobs)

A sample extlinux.conf file is provided in the [examples](examples) directory.

## Build

Clone the repository and build Talos Linux for Orange Pi 5:

```bash
git clone https://github.com/si0ls/talos-orangepi5.git
cd talos-orangepi5
make
```

The image will be available in the `out` directory.

_The detail of all the build steps and parameters can be found in the [Makefile](Makefile)._

## Special thanks

- [Sidero Labs](https://www.siderolabs.com/) for the Talos project
- [Armbian](https://www.armbian.com/) for the rk3588 kernel
- [@nberlee](https://github.com/nberlee) and [@pl4nty](https://github.com/pl4nty) for the initial work on other rk3588 devices and their help ❤️
