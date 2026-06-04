{
  description = "Microcode updates for AMD CPUs on NixOS";

  inputs.cpu-microcodes = {
    url = "github:platomav/CPUMicrocodes";
    flake = false;
  };

  outputs =
    { self, cpu-microcodes, ... }:
    {
      nixosModules.default =
        { lib, ... }:
        {
          imports = [ ./modules/nixos.nix ];
          services.ucodenix.cpu-microcodes = lib.mkDefault cpu-microcodes;
        };

      nixosModules.ucodenix = self.nixosModules.default;
    };
}
