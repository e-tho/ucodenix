<div align="center">
  <h1>ucodenix</h1>
</div>

## About

`ucodenix` is a Nix flake that automates the generation and integration of AMD microcode updates.

> Microcodes are fetched from [this repository](https://github.com/platomav/CPUMicrocodes), which aggregates them from official sources provided and made public by various manufacturers.

## Features

- Fetches the microcode binary based on your processor's serial number.
- Generates the microcode container as used by the Linux kernel.
- Integrates the generated microcode into the NixOS configuration.

## Installation

Add the flake as an input:

```nix
ucodenix.url = "github:e-tho/ucodenix";
```

## Usage

Install `cpuid` and run the following command to retrieve your processor's serial number:

```shell
cpuid | sed -n 's/^.*processor serial number = //p' | head -n1
```

Enable the NixOS module and set your processor's serial number:

```nix
{ inputs, ... }:
{
  imports = [ inputs.ucodenix.nixosModules.ucodenix ];

  services.ucodenix = {
    enable = true;
    cpuSerialNumber = "00A2-0F12-0000-0000-0000-0000"; # Replace with your processor's serial number
  };
}

```

Rebuild your NixOS configuration:

```sh
sudo nixos-rebuild switch
```

## Disclaimer

This software is provided "as is" without any guarantees. Use at your own risk.

## License

GPLv3
