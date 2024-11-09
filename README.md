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

Enable the NixOS module by adding the following to your configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.ucodenix.nixosModules.ucodenix ];

  services.ucodenix.enable = true;
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
