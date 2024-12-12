{
  description = "Nix flake providing AMD microcode updates for unsupported CPUs";

  inputs.cpu-microcodes = {
    url = "github:platomav/CPUMicrocodes/06ffdd1bcc222f2e63d8e1d0dcbeb5c23ebdcf99";
    flake = false;
  };

  outputs = { self, cpu-microcodes, ... }:
    let
      ucodenix =
        { stdenv
        , lib
        , amd-ucodegen
        , cpuModelId
        }: stdenv.mkDerivation {
          pname = "ucodenix";
          version = "1.2.0";

          src = cpu-microcodes;

          nativeBuildInputs = [ amd-ucodegen ];

          buildPhase = ''
            temp_dir=$(mktemp -d)
            mkdir -p "$temp_dir"

            if [ "${cpuModelId}" = "auto" ]; then
              find $src/AMD -name "*.bin" -print0 | sort -z | \
              while IFS= read -r -d ''' file; do
                output_file="$temp_dir/$(basename "$file")"
                amd-ucodegen -o "$output_file" "$file" || {
                  echo "Warning: Failed to process $file. Skipping."
                  continue
                }
              done

              find "$temp_dir" -type f -name "*.bin" -print0 | \
                xargs -0 -I{} sh -c 'cat "$1" >> "$2"' -- {} "$temp_dir/AuthenticAMD.bin"

            else
              find $src/AMD -name "cpu${cpuModelId}*.bin" -exec cp {} "$temp_dir/microcode.bin" \;
              if [ ! -f "$temp_dir/microcode.bin" ]; then
                echo "No microcode found with model ${cpuModelId}"
                exit 1
              fi
              amd-ucodegen -o "$temp_dir/AuthenticAMD.bin" "$temp_dir/microcode.bin"
            fi

            if [ ! -f "$temp_dir/AuthenticAMD.bin" ]; then
              echo "Error: Failed to generate AuthenticAMD.bin."
              exit 1
            fi

            mkdir -p kernel/x86/microcode
            cp "$temp_dir/AuthenticAMD.bin" kernel/x86/microcode/

            rm -rf "$temp_dir"
          '';

          installPhase = ''
            mkdir -p $out/kernel/x86/microcode
            cp -r kernel/x86/microcode/* $out/kernel/x86/microcode/
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
              default = "auto";
              description = ''
                The CPU model ID used to determine the appropriate microcode binary file.
                Set to "auto" to enable processing of all available microcode binaries.
                Defaults to "auto".
              '';
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

            hardware.cpu.amd.updateMicrocode = true;
          };

          imports = [
            (lib.mkRemovedOptionModule [ "services" "ucodenix" "cpuSerialNumber" ] "Please use `ucodenix.cpuModelId` instead. This option takes a different format, refer to the documentation to obtain your `cpuModelId`.")
          ];
        };

      nixosModules.ucodenix = self.nixosModules.default;
    };
}
