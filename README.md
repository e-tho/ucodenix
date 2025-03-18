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

### 2. (Optional) Specify Your Processor's Model ID

By default, `ucodenix` processes all available microcode binaries, each intended for a specific CPUID identifying a family of CPUs. This behavior is controlled by setting `cpuModelId` to `"auto"`. The Linux kernel automatically detects and loads the appropriate microcode at boot time.

If you prefer, you can manually specify your processor's model ID to process only the binary needed for your CPU. This reduces the output size and simplifies the build artifacts, making them more focused for targeted deployments.

#### Retrieve Your Processor's Model ID

There are two ways to specify your processor's model ID:

1. **Directly Provide the Model ID**

You can retrieve the model ID using the `cpuid` tool. Install it and run the following command:

```shell
cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p'
```

Update your configuration with the retrieved model ID:

```nix
services.ucodenix = {
  enable = true;
  cpuModelId = "00A20F12"; # Replace with your processor's model ID
};
```

2. **Use a NixOS Facter Report File**

If you use [NixOS Facter](https://github.com/numtide/nixos-facter), you can specify the path to its generated `facter.json` report file for `ucodenix` to compute the model ID. Run the following command to generate your report file:

```shell
sudo nix run nixpkgs#nixos-facter -- -o facter.json
```

Update your configuration with the file path:

```nix
services.ucodenix = {
  enable = true;
  cpuModelId = ./path/to/facter.json; # Or config.facter.reportPath if specified
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

> [!IMPORTANT]
>
> The microcodes introduced in early 2025 cannot be loaded without a BIOS version that explicitly addresses the signature verification vulnerability (CVE-2024-56161). If your BIOS does not include the necessary patches, the system will fail to apply the microcode update, resulting in boot-time warnings such as:
>
> ```console
> [    0.001271] microcode: CPU1: update failed for patch_level=0x0a201213
> ```
>
> You must either update your BIOS to the latest version, ensuring it is dated after early 2025 and that its release notes mention the fix for the signature verification vulnerability, or freeze the last supported microcode version by explicitly pinning the repository in your Nix flake inputs, as shown below:
>
> ```nix
> inputs = {
>   cpu-microcodes = {
>     url = "github:platomav/CPUMicrocodes/ec5200961ecdf78cf00e55d73902683e835edefd";
>     flake = false;
>   };
>   ucodenix = {
>     url = "github:e-tho/ucodenix";
>     inputs.cpu-microcodes.follows = "cpu-microcodes";
>   };
> };
> ```

> [!IMPORTANT]
>
> The Linux kernel now verifies microcode against a list of approved SHA256 checksums. Since `ucodenix` fetches microcode binaries aggregated from various sources by [CPUMicrocodes](https://github.com/platomav/CPUMicrocodes), they may differ from the officially approved checksums even though their content is functionally identical.
> If you encounter this error:
>
> ```console
> [    0.001272] microcode: No sha256 digest for patch ID: 0x8701035 found
> ```
>
> You will need to disable this feature for the microcode to load:
>
> ```nix
> boot.kernelParams = [ "microcode.amd_sha_check=off" ];
> ```

## FAQ

### Why would I need this if AMD already provides microcodes for Linux?

AMD only provides microcodes to `linux-firmware` for certain server-grade CPUs. For consumer CPUs, updates are distributed through BIOS releases by motherboard and laptop manufacturers, which can be inconsistent, delayed, or even discontinued over time. This flake ensures you have the latest microcodes directly on NixOS, without depending on BIOS updates.

### Is there any risk in using this flake?

The microcodes are obtained from official sources and are checked for integrity and size. The Linux kernel has built-in safeguards and will only load microcode that is compatible with your CPU, otherwise defaulting to the BIOS-provided version. As a result, using this flake can be considered safe and should carry no significant risks.

## Disclaimer

This software is provided "as is" without any guarantees.

## License

GPLv3
