# GooseOS &nbsp; [![Intel Build](https://github.com/iegorch86/homelabos/actions/workflows/build-intel.yml/badge.svg)](https://github.com/iegorch86/homelabos/actions/workflows/build-intel.yml) [![NVIDIA Build](https://github.com/iegorch86/homelabos/actions/workflows/build-nvidia.yml/badge.svg)](https://github.com/iegorch86/homelabos/actions/workflows/build-nvidia.yml)

<p align="center">
  <img src="assets/main-logo.png" alt="GooseOS Logo" width="280">
</p>

<h1 align="center">GooseOS</h1>

<p align="center">
  <strong>Personal Fedora Atomic COSMIC image built with BlueBuild.</strong><br>
  Fast. Stable. Canadian.
</p>

## What is GooseOS?

GooseOS is my personal [Fedora Atomic](https://fedoraproject.org/atomic-desktops/) workstation image with Cosmic desktop built with [BlueBuild](https://blue-build.org/).

It started as a way to create a clean, reproducible desktop that contains the applications, tools, and configuration I use every day, without reinstalling or manually configuring a new system each time.

The project combines ideas from Fedora Atomic, [Universal Blue](https://universal-blue.org/), [Bluefin](https://projectbluefin.io/), and BlueBuild while remaining a custom image tailored to my own workflow. Some package and configuration choices are inspired by Bluefin, with adjustments based on my own experience and requirements.

Although GooseOS is built primarily for personal use, anyone is welcome to test it in a virtual machine or on real hardware. It is an experimental custom image, so users should review the recipes and understand what is included before installing it.

### Goals

- Clean and reproducible Fedora Atomic workstation
- Separate Intel/Generic and NVIDIA Open images
- COSMIC desktop with a carefully selected application set
- Minimal manual setup after installation
- Automated image builds through GitHub Actions
- Learning how the custom Atomic system model works
- Applying that knowledge across my Fedora Atomic desktop and my uCore/Fedora CoreOS home server

## BlueBuild_Docs

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]
> These are personal experimental Fedora Atomic images. Use them at your own discretion.

Two variants are available:

- **GooseOS NVIDIA** — for systems using supported NVIDIA graphics and the NVIDIA open kernel modules.
- **GooseOS Intel (Generic)** — for Intel, AMD, virtual machines, and systems that do not require the NVIDIA driver.

### NVIDIA version

First rebase to the unsigned image:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/iegorch86/gooseos-nvidia-open:latest
```

Reboot:

```bash
systemctl reboot
```

Then switch to the signed image:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/iegorch86/gooseos-nvidia-open:latest
```

Reboot again:

```bash
systemctl reboot
```

### Intel / generic version

First rebase to the unsigned image:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/iegorch86/gooseos-intel:latest
```

Reboot:

```bash
systemctl reboot
```

Then switch to the signed image:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/iegorch86/gooseos-intel:latest
```

Reboot again:

```bash
systemctl reboot
```

The `latest` tag points to the newest build of each variant.

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/iegorch86/homelabos
```
