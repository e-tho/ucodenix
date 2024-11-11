<div align="center">
  <h1>ucodenix</h1>
</div>

## About

`ucodenix` is a Nix flake providing AMD microcode updates for unsupported CPUs.

> [!NOTE]
> Microcodes are fetched from [this repository](https://github.com/platomav/CPUMicrocodes), which aggregates them from official sources provided and made public by various manufacturers.

## Features

- Fetches the microcode binary based on your processor's model ID.
- Generates the microcode container as used by the Linux kernel.
- Integrates the generated microcode into the NixOS configuration.

## Installation

Add the flake as an input:

```nix
inputs.ucodenix.url = "github:e-tho/ucodenix";
```

## Usage

Enable the NixOS module by adding the following to your configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  services.ucodenix.enable = true;
}

```

Rebuild your NixOS configuration:

```sh
sudo nixos-rebuild switch
```

## FAQ

### Why would I need this if AMD provides microcodes to `linux-firmware`?

AMD only supplies microcodes to `linux-firmware` for certain server-grade CPUs. For consumer CPUs, updates are distributed through BIOS releases by motherboard and laptop manufacturers, which can be inconsistent, delayed, or even discontinued over time. This flake ensures you have the latest microcodes directly on NixOS, without depending on BIOS updates.

### Is there any risk in using this flake?

The microcodes are obtained from official sources and are checked for integrity and size. The Linux kernel has built-in safeguards and will only load microcode that is compatible with your CPU, otherwise defaulting to the BIOS-provided version.

## Disclaimer

This software is provided "as is" without any guarantees.

## License

GPLv3
