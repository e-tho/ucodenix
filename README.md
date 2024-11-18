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

Install `cpuid` and run the following command to retrieve your processor's model ID:

```shell
cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p'
```

Enable the ucodenix NixOS module and set the model ID in your configuration:

```nix
{ inputs, ... }:
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  services.ucodenix = {
    enable = true;
    cpuModelId = "00A20F12"; # Replace with your processor's model ID
  };
}
```

Setting `cpuModelId` to `"auto"` enables automatic detection of the CPU model ID at build time. Note that this makes the build non-reproducible, so specifying `cpuModelId` manually is recommended.

> [!TIP]
>
> To confirm that the microcode has been updated, run:
>
> ```shell
> sudo dmesg | grep microcode
> ```
>
> If the update was successful, you should see output like this:
>
> ```shell
> # For kernel versions >= v6.6:
> [    0.509186] microcode: Current revision: 0x0a201210
> [    0.509188] microcode: Updated early from: 0x0a201205
>
> # For kernel versions < v6.6:
> [    0.509188] microcode: microcode updated early to new patch_level=0x0a201210
> ```
>
> Keep in mind that the provided microcode might not be newer than the one from your BIOS.

## FAQ

### Why would I need this if AMD already provides microcodes for Linux?

AMD only provides microcodes to `linux-firmware` for certain server-grade CPUs. For consumer CPUs, updates are distributed through BIOS releases by motherboard and laptop manufacturers, which can be inconsistent, delayed, or even discontinued over time. This flake ensures you have the latest microcodes directly on NixOS, without depending on BIOS updates.

### Is there any risk in using this flake?

The microcodes are obtained from official sources and are checked for integrity and size. The Linux kernel has built-in safeguards and will only load microcode that is compatible with your CPU, otherwise defaulting to the BIOS-provided version. As a result, using this flake can be considered safe and should carry no significant risks.

## Disclaimer

This software is provided "as is" without any guarantees.

## License

GPLv3
