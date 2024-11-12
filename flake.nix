{
  description = "ucodenix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };
      lib = pkgs.lib;

      ucodenix = cpuModelId: pkgs.stdenv.mkDerivation rec {
        pname = "ucodenix";
        version = "1.1.0";

        src = pkgs.fetchFromGitHub {
          owner = "platomav";
          repo = "CPUMicrocodes";
          rev = "7d439ddf43c75a9ef410b40608c0cb545d722c30";
          hash = "sha256-cpFAvnLg0OSH+sa0EkojovGRui5joV2cDcFEd2Rnqts=";
        };

        nativeBuildInputs = [ pkgs.amd-ucodegen ] ++ lib.optionals (cpuModelId == "auto") [ pkgs.cpuid ];

        unpackPhase = ''
          mkdir -p $out
          if [ "${cpuModelId}" = "auto" ]; then
            modelResult=$(cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p')
          else
            modelResult="${cpuModelId}"
          fi
          microcodeFile=$(find $src/AMD -name "cpu$modelResult*.bin" | head -n 1)
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
          license = lib.licenses.gpl3;
          platforms = lib.platforms.linux;
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

            cpuModelId = lib.mkOption {
              type = lib.types.str;
              default = "";
              example = "\"00A20F12\" or \"auto\"";
              description = "The CPU model ID used to determine the appropriate microcode binary file. Set to \"auto\" to automatically detect the model ID.";
            };

            cpuSerialNumber = lib.mkOption {
              type = lib.types.nullOr lib.types.str;
              default = null;
              description = "The processor's serial number, used to determine the appropriate microcode binary file (deprecated).";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = with pkgs; [
              (ucodenix cfg.cpuModelId)
            ];

            nixpkgs.overlays = [
              (final: prev: {
                microcode-amd = prev.microcode-amd.overrideAttrs (oldAttrs: rec {
                  buildPhase = ''
                    mkdir -p kernel/x86/microcode
                    cp ${(ucodenix cfg.cpuModelId)}/kernel/x86/microcode/AuthenticAMD.bin kernel/x86/microcode/AuthenticAMD.bin
                  '';

                  installPhase = ''
                    mkdir -p $out
                    touch -d @$SOURCE_DATE_EPOCH kernel/x86/microcode/AuthenticAMD.bin
                    echo kernel/x86/microcode/AuthenticAMD.bin | bsdtar --uid 0 --gid 0 -cnf - -T - | bsdtar --null -cf - --format=newc @- > $out/amd-ucode.img
                  '';
                });
              })
            ];

            assertions = lib.concatLists [
              (lib.optionals (cfg.cpuModelId == "" && cfg.cpuSerialNumber == null) [
                {
                  assertion = false;
                  message = "The `ucodenix.cpuModelId` option is required. Please refer to the documentation to obtain your CPU model ID.";
                }
              ])

              (lib.optionals (cfg.cpuModelId == "" && cfg.cpuSerialNumber != null) [
                {
                  assertion = false;
                  message = "The `ucodenix.cpuSerialNumber` option is deprecated and has been replaced by `cpuModelId`, which uses a different format. Please refer to the documentation to obtain your `cpuModelId`.";
                }
              ])
            ];

            warnings = lib.optionals (cfg.cpuModelId == "auto") [
              "ucodenix: Setting `cpuModelId` to \"auto\" results in a non-reproducible build."
            ];
          };
        };

      nixosModules.ucodenix = self.nixosModules.default;
    };
}
