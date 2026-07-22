<p align="center">
  <img src="assets/main-logo.png" alt="GooseOS Logo" width="300">
</p>

<h1 align="center">GooseOS</h1>

<p align="center">
  <strong>Personal Fedora Atomic COSMIC image built with BlueBuild.</strong><br>
  Fast. Stable. Canadian.
</p>

 [![TEST Build](https://github.com/iegorch86/homelabos/actions/workflows/build-cosmic-test.yml/badge.svg)](https://github.com/iegorch86/homelabos/actions/workflows/build-cosmic-test.yml) 

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
- Included driver for Pantum MFP
- Automated image builds through GitHub Actions
- Learning how the custom Atomic system model works
- Applying that knowledge across my Fedora Atomic desktop and my uCore/Fedora CoreOS home server

## BlueBuild Documentation

See the [BlueBuild docs](https://blue-build.org/how-to/setup/) for quick setup instructions for setting up your own repository based on this template.

After setup, it is recommended you update this README to describe your custom image.

## Installation

> [!WARNING]
> These are personal experimental Fedora Atomic images. Use them at your own discretion.

GooseOS is currently intended to be installed by rebasing an existing **Fedora COSMIC Atomic** system.

Install Fedora COSMIC Atomic first using the official Fedora image: [Download Fedora COSMIC Atomic](https://fedoraproject.org/atomic-desktops/cosmic/download/)

After the initial Fedora installation is complete, rebase to the appropriate GooseOS image.

GooseOS has not been tested as a rebase target from other Fedora Atomic desktops or other bootc-based distributions.

Two variants are available:

- **GooseOS NVIDIA** — for systems using supported NVIDIA graphics and the NVIDIA open kernel modules.
- **GooseOS Intel/AMD** — for Intel, AMD, virtual machines, and systems that do not require the NVIDIA driver.

### NVIDIA version

First rebase to the unsigned image:

```bash
rpm-ostree rebase ostree-unverified-registry:ghcr.io/iegorch86/gooseos-cosmic-test:br-testing-44
```

Reboot:

```bash
systemctl reboot
```

Then switch to the signed image:

```bash
rpm-ostree rebase ostree-image-signed:docker://ghcr.io/iegorch86/gooseos-cosmic-test:br-testing-44
```

Reboot again:

```bash
systemctl reboot
```

## ISO

If build on Fedora Atomic, you can generate an offline ISO with the instructions available [here](https://blue-build.org/how-to/generate-iso/#_top). These ISOs cannot unfortunately be distributed on GitHub for free due to large sizes, so for public projects something else has to be used for hosting.

## Verification

These images are signed with [Sigstore](https://www.sigstore.dev/)'s [cosign](https://github.com/sigstore/cosign). You can verify the signature by downloading the `cosign.pub` file from this repo and running the following command:

```bash
cosign verify --key cosign.pub ghcr.io/iegorch86/homelabos
```
## Why a Canada Goose?

GooseOS needed a mascot, and a Canada goose was the obvious choice.

If you've ever lived in Canada, you probably already know why.

They're affectionately known as **cobra chickens**—a nickname earned by confidently taking ownership of sidewalks, parks, parking lots, and occasionally your personal space.

If you've encountered one, no further explanation is necessary.

No geese were annoyed during the build process
...that we know of.
