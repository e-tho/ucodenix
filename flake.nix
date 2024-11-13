{
  description = "ucodenix flake";

  outputs = { self, ... }:
    let
      ucodenix =
      { stdenv
      , lib
      , fetchFromGitHub
      , amd-ucodegen
      , cpuid

      , cpuModelId
      }: stdenv.mkDerivation {
        pname = "ucodenix";
        version = "1.1.0";

        src = fetchFromGitHub {
          owner = "platomav";
          repo = "CPUMicrocodes";
          rev = "7d439ddf43c75a9ef410b40608c0cb545d722c30";
          hash = "sha256-cpFAvnLg0OSH+sa0EkojovGRui5joV2cDcFEd2Rnqts=";
        };

        nativeBuildInputs = [ amd-ucodegen ] ++ lib.optionals (cpuModelId == "auto") [ cpuid ];

        buildPhase = ''
          if [ "${cpuModelId}" = "auto" ]; then
            modelResult=$(cpuid -1 -l 1 -r | sed -n 's/.*eax=0x\([0-9a-f]*\).*/\U\1/p')
          else
            modelResult="${cpuModelId}"
          fi
          find $src/AMD -name "cpu$modelResult*.bin" -exec cp {} microcode.bin \;

          if [ ! -f microcode.bin ]; then
            echo "No microcode found with model $modelResult"
            exit 1
          fi

          mkdir -p $out/kernel/x86/microcode
          amd-ucodegen -o $out/kernel/x86/microcode/AuthenticAMD.bin microcode.bin
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
              example = "\"00A20F12\" or \"auto\"";
              description = "The CPU model ID used to determine the appropriate microcode binary file. Set to \"auto\" to automatically detect the model ID.";
            };
          };

          config = lib.mkIf cfg.enable {
            nixpkgs.overlays = [
              (final: prev: {
                ucodenix = final.callPackage ucodenix { inherit (cfg) cpuModelId; };

                microcode-amd = final.stdenv.mkDerivation {
                  name = "amd-ucode";
                  src = final.ucodenix;

                  nativeBuildInputs = [ final.libarchive ];

                  installPhase = ''
                    mkdir -p $out
                    touch -d @$SOURCE_DATE_EPOCH kernel/x86/microcode/AuthenticAMD.bin
                    echo kernel/x86/microcode/AuthenticAMD.bin | bsdtar --uid 0 --gid 0 -cnf - -T - | bsdtar --null -cf - --format=newc @- > $out/amd-ucode.img
                  '';
                };
              })
            ];

            # we overwrote the package used in this option
            hardware.cpu.amd.updateMicrocode = true;

            warnings = lib.optionals (cfg.cpuModelId == "auto") [
              "ucodenix: Setting `cpuModelId` to \"auto\" results in a non-reproducible build."
            ];
          };

          imports = [
            (lib.mkRemovedOptionModule [ "services" "ucodenix" "cpuSerialNumber" ] "Please use `ucodenix.cpuModelId` instead. This option takes a different format, refer to the documentation to obtain your `cpuModelId`.")
          ];
        };

      nixosModules.ucodenix = self.nixosModules.default;
    };
}
