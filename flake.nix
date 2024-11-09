{
  description = "ucodenix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };

      ucodenix = pkgs.stdenv.mkDerivation rec {
        pname = "ucodenix";
        version = "1.0.0";

        src = pkgs.fetchFromGitHub {
          owner = "platomav";
          repo = "CPUMicrocodes";
          rev = "7d439ddf43c75a9ef410b40608c0cb545d722c30";
          hash = "sha256-cpFAvnLg0OSH+sa0EkojovGRui5joV2cDcFEd2Rnqts=";
        };

        nativeBuildInputs = with pkgs; [ amd-ucodegen cpuid ];

        unpackPhase = ''
          mkdir -p $out
          serialResult=$(cpuid -1 -l 1 -r | sed -n 's/^ *0x00000001 0x00: eax=0x\([0-9a-f]*\).*/\U\1/p')
          microcodeFile=$(find $src/AMD -name "cpu$serialResult*.bin" | head -n 1)
          cp $microcodeFile $out/$(basename $microcodeFile) || (echo "File not found: $microcodeFile" && exit 1)
        '';

        buildPhase = ''
          mkdir -p $out/kernel/x86/microcode
          microcodeFile=$(find $out -name "cpu*.bin" | head -n 1)
          amd-ucodegen $microcodeFile
          mv microcode_amd*.bin $out/kernel/x86/microcode/AuthenticAMD.bin
        '';

        meta = {
          description = "Generated AMD microcode for CPU";
          license = pkgs.lib.licenses.gpl3;
          platforms = pkgs.lib.platforms.linux;
        };
      };

    in
    {
      nixosModules.default =
        { config
        , lib
        , pkgs
        , ...
        }:

        let
          cfg = config.services.ucodenix;
        in
        {
          options.services.ucodenix = {
            enable = lib.mkEnableOption "ucodenix service";

            cpuSerialNumber = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The processor's serial number, used to determine the appropriate microcode binary file (deprecated).";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = with pkgs; [
              ucodenix
            ];

            nixpkgs.overlays = [
              (final: prev: {
                microcodeAmd = prev.microcodeAmd.overrideAttrs (oldAttrs: rec {
                  buildPhase = ''
                    mkdir -p kernel/x86/microcode
                    cp ${ucodenix}/kernel/x86/microcode/AuthenticAMD.bin kernel/x86/microcode/AuthenticAMD.bin
                  '';
                });
              })
            ];

            warnings = lib.optionals (cfg.cpuSerialNumber != null) [
              "ucodenix: The `services.ucodenix.cpuSerialNumber` option is deprecated and can be removed; the processor's serial number is now determined automatically."
            ];
          };
        };

      nixosModules.ucodenix = self.nixosModules.default;
    };
}
