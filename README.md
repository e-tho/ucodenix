<div align="center">
  <h1>ucodenix</h1>
</div>

## About

`ucodenix` delivers microcode updates for AMD CPUs on NixOS.

Supports consumer and server-grade platforms, regardless of BIOS updates or manufacturer delays.

> [!NOTE]
> Microcodes are fetched from [this repository](https://github.com/platomav/CPUMicrocodes), which aggregates them from official sources provided and made public by various manufacturers.

## Features

- Fetches AMD microcode binaries from a repository aggregating updates from official sources.
- Processes the microcode binaries to generate a container compatible with the Linux kernel.
- Integrates the generated microcode seamlessly into the NixOS configuration.
- Supports automatic processing or custom selection based on your CPU model.

## Usage

### With flakes

#### 1. Add the flake input

```nix
inputs.ucodenix.url = "github:e-tho/ucodenix";
```

#### 2. Enable the module

```nix
{ inputs, ... }:
{
  imports = [ inputs.ucodenix.nixosModules.default ];

  services.ucodenix.enable = true;
}
```

#### 3. (Optional) Specify your processor's model ID

See [Retrieving your processor's model ID](#retrieving-your-processors-model-id).

#### 4. Apply changes

Rebuild your configuration and reboot to apply the microcode update.

```shell
nixos-rebuild boot --sudo --flake path/to/flake/directory
```

### Without flakes

#### 1. Add the flake input

```nix
inputs.ucodenix = {
  url = "github:e-tho/ucodenix";
  flake = false;
};
```

#### 2. Import the module

```nix
{ inputs, ... }:
{
  imports = [ "${inputs.ucodenix}/modules/nixos.nix" ];
}
```

#### 3. Provide the cpu-microcodes source

The source is resolved automatically by default. To override it:

```nix
{ pkgs, ... }:
{
  services.ucodenix.cpu-microcodes = pkgs.fetchFromGitHub {
    owner = "platomav";
    repo = "CPUMicrocodes";
    rev = ""; # pin a specific revision
    hash = "";
  };
}
```

#### 4. Enable the module

```nix
{
  services.ucodenix.enable = true;
}
```

#### 5. (Optional) Specify your processor's model ID

See [Retrieving your processor's model ID](#retrieving-your-processors-model-id).

#### 6. Apply changes

Rebuild your configuration and reboot to apply the microcode update.

```shell
nixos-rebuild boot --sudo
```

### Retrieving your processor's model ID

By default, `ucodenix` processes all available microcode binaries, each intended for a specific CPUID identifying a family of CPUs. The Linux kernel automatically detects and loads the appropriate microcode at boot time.

You can optionally specify your processor's model ID to process only the binary needed for your CPU. This reduces the output size and simplifies the build artifacts, making them more focused for targeted deployments.

There are two ways to provide it:

#### 1. Directly provide the model ID

Install the `cpuid` tool and run:

```shell
cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p'
```

Then set it in your configuration:

```nix
services.ucodenix.cpuModelId = "00A20F12"; # replace with your processor's model ID
```

#### 2. Use a NixOS Facter report file

If you use [NixOS Facter](https://github.com/numtide/nixos-facter), generate a report file:

```shell
sudo nix run nixpkgs#nixos-facter -- -o facter.json
```

Then point to it in your configuration:

```nix
services.ucodenix.cpuModelId = ./path/to/facter.json; # or config.facter.reportPath if specified
```

### Verifying the update

After rebuilding and rebooting, confirm the microcode was applied:

```shell
sudo dmesg | grep microcode
```

If the update was successful, you should see output like this:

```shell
# For kernel versions >= v6.6:
[    0.509186] microcode: Current revision: 0x0a201210
[    0.509188] microcode: Updated early from: 0x0a201205

# For kernel versions < v6.6:
[    0.509188] microcode: microcode updated early to new patch_level=0x0a201210
```

Note that the provided microcode might not be newer than the one from your BIOS.

## Troubleshooting

### Microcode fails SHA256 verification

The Linux kernel verifies microcode against a list of approved SHA256 checksums. Since `ucodenix` fetches microcode binaries aggregated from various sources by [CPUMicrocodes](https://github.com/platomav/CPUMicrocodes), they may differ from the officially approved checksums even though their content is functionally identical.

If you encounter this error:

```console
[    0.001272] microcode: No sha256 digest for patch ID: 0x8701035 found
```

Disable the check:

```nix
boot.kernelParams = [ "microcode.amd_sha_check=off" ];
```

### Microcode fails to load after a BIOS update

Microcodes introduced in early 2025 cannot be loaded without a BIOS version that explicitly addresses the signature verification vulnerability (CVE-2024-56161). If your BIOS does not include the necessary patches, you will see boot-time warnings such as:

```console
[    0.001271] microcode: CPU1: update failed for patch_level=0x0a201213
```

Update your BIOS to a version dated after early 2025 whose release notes mention the fix for CVE-2024-56161. If your manufacturer has not released such an update, pin the last supported microcode revision:

```nix
inputs = {
  cpu-microcodes = {
    url = "github:platomav/CPUMicrocodes/ec5200961ecdf78cf00e55d73902683e835edefd";
    flake = false;
  };
  ucodenix = {
    url = "github:e-tho/ucodenix";
    inputs.cpu-microcodes.follows = "cpu-microcodes";
  };
};
```

## FAQ

### Why would I need this if AMD already provides microcodes for Linux?

AMD distributes microcode updates primarily through BIOS releases, which can be inconsistent, delayed, or discontinued. While AMD does provide some microcode updates directly through `linux-firmware`, coverage is limited to a subset of CPU models, with many being outdated. `ucodenix` uses microcodes aggregated from official sources to provide broader support and more current updates. This ensures your system receives the latest microcode patches, including critical security fixes, without relying on BIOS updates from your manufacturer or the limited `linux-firmware` coverage from AMD.

### Is there any risk in using this flake?

The microcodes are obtained from official sources and are checked for integrity and size. The Linux kernel has built-in safeguards and will only load microcode that is compatible with your CPU, otherwise defaulting to the BIOS-provided version. As a result, using this flake can be considered safe and should carry no significant risks.

## Disclaimer

This software is provided "as is" without any guarantees.

## License

GPLv3
