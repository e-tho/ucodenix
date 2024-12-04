<div align="center">
  <h1>ucodenix</h1>
</div>

## About

`ucodenix` is a Nix flake providing AMD microcode updates for unsupported CPUs.

> [!NOTE]
> Microcodes are fetched from [this repository](https://github.com/platomav/CPUMicrocodes), which aggregates them from official sources provided and made public by various manufacturers.

## Features

- Fetches AMD microcode binaries from a repository aggregating updates from official sources.
- Processes the microcode binaries to generate a container compatible with the Linux kernel.
- Integrates the generated microcode seamlessly into the NixOS configuration.
- Supports automatic processing or custom selection based on your CPU model.

## Installation

Add the flake as an input:

```nix
inputs.ucodenix.url = "github:e-tho/ucodenix";
```

## Usage

### 1. Enable the Module

Enable the `ucodenix` NixOS module:

```nix
{ inputs, ... }:
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  services.ucodenix.enable = true;
}
```

### 2. (Optional) Specify Your Processor Model ID

By default, `ucodenix` processes all available microcode binaries, each intended for a specific CPUID identifying a family of CPUs. This behavior is controlled by setting `cpuModelId` to `"auto"`. The Linux kernel automatically detects and loads the appropriate microcode at boot time.

If you prefer, you can manually specify your processor's model ID to process only the binary needed for your CPU. This reduces the output size and simplifies the build artifacts, making them more focused for targeted deployments.

#### Retrieve Your Processor's Model ID

To retrieve your processor's model ID, install `cpuid` and run the following command:

```shell
cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p'
```

#### Update Your Configuration

Once you have the model ID, update your configuration as follows:

```nix
services.ucodenix = {
  enable = true;
  cpuModelId = "00A20F12"; # Replace with your processor's model ID
};
```

### 3. Apply Changes

Rebuild your configuration and reboot to apply the microcode update.

```shell
sudo nixos-rebuild switch --flake path/to/flake/directory
```

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
