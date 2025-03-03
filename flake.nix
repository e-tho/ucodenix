{
  description = "Nix flake providing AMD microcode updates for unsupported CPUs";

  inputs.cpu-microcodes = {
    url = "github:platomav/CPUMicrocodes/f22581017de2d0a67b9fb4109ea04b5fda649966";
    flake = false;
  };

  outputs = { self, cpu-microcodes, ... }:
    let
      ucodenix =
        { stdenv
        , lib
        , amd-ucodegen
        , jql
        , cpuModelId
        }: stdenv.mkDerivation {
          pname = "ucodenix";
          version = "1.3.0";

          src = cpu-microcodes;

          nativeBuildInputs = [ amd-ucodegen ] ++ lib.optionals (lib.isPath cpuModelId && builtins.pathExists cpuModelId) [ jql ];

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

              temp_output="$temp_dir/AuthenticAMD.temp"
              find "$temp_dir" -type f -name "*.bin" -print0 | \
                xargs -0 -I{} cat {} >> "$temp_output"
              mv "$temp_output" "$temp_dir/AuthenticAMD.bin"

            elif [ -f "${cpuModelId}" ]; then

              family=$(jql '"hardware" "cpu" [0] "family"' "${cpuModelId}")
              model=$(jql '"hardware" "cpu" [0] "model"' "${cpuModelId}")
              stepping=$(jql '"hardware" "cpu" [0] "stepping"' "${cpuModelId}")

              extFamily=$((family > 15 ? family - 15 : 0))
              extModel=$((model / 16))
              baseFamily=$((family > 15 ? 15 : family))
              baseModel=$((model % 16))

              eax=$((extFamily * 1048576 + extModel * 65536 + baseFamily * 256 + baseModel * 16 + stepping))
              modelResult=$(printf "%08X" $eax)

            else
              modelResult="${cpuModelId}"
              echo "Using CPU model ID directly: ''${modelResult}"
            fi

            if [ "${cpuModelId}" != "auto" ]; then
              find $src/AMD -name "cpu''${modelResult}*.bin" -exec cp {} "$temp_dir/microcode.bin" \;
              if [ ! -f "$temp_dir/microcode.bin" ]; then
                echo "No microcode found with model ''${modelResult}"
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
              type = lib.types.either lib.types.str lib.types.path;
              example = "\"auto\" or \"00A20F12\" or \"/path/to/facter.json\"";
              default = "auto";
              description = ''
                Specifies the CPU model ID to determine the appropriate microcode binary file. 
                Accepts a literal model ID (e.g., "00A20F12") or a path to a `facter.json` file 
                generated by `nixos-facter` to extract the model ID. Defaults to "auto", which processes 
                all available microcode binaries.
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
