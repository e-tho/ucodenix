{
  description = "ucodenix flake";

  inputs.nixpkgs.url = "github:NixOS/nixpkgs/nixos-unstable";

  outputs = { self, nixpkgs, ... }:
    let
      pkgs = import nixpkgs { system = "x86_64-linux"; };

      ucodenix = { cpuSerialNumber }: pkgs.stdenv.mkDerivation rec {
        pname = "ucodenix";
        version = "1.0.0";

        src = pkgs.fetchFromGitHub {
          owner = "platomav";
          repo = "CPUMicrocodes";
          rev = "e605d60009ab1af7d1cd2d08c2e235ab09ffeaf1";
          hash = "sha256-J7lXxo0MHAghlGlsbliSXvaOSSxiSRpP9TJmUm8eWb0=";
        };

        nativeBuildInputs = [ pkgs.amd-ucodegen ];

        unpackPhase = ''
          mkdir -p $out
          serialResult=$(echo "${cpuSerialNumber}" | sed 's/.* = //;s/-0000.*//;s/-//')
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
      nixosModules.ucodenix =
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
              type = lib.types.str;
              description = "The processor's serial number, used to determine the appropriate microcode binary file.";
            };
          };

          config = lib.mkIf cfg.enable {
            environment.systemPackages = with pkgs; [
              (ucodenix { cpuSerialNumber = cfg.cpuSerialNumber; })
            ];

            nixpkgs.overlays = [
              (final: prev: {
                microcodeAmd = prev.microcodeAmd.overrideAttrs (oldAttrs: rec {
                  buildPhase = ''
                    mkdir -p kernel/x86/microcode
                    cp ${ucodenix { cpuSerialNumber = cfg.cpuSerialNumber; }}/kernel/x86/microcode/AuthenticAMD.bin kernel/x86/microcode/AuthenticAMD.bin
                  '';
                });
              })
            ];
          };
        };
    };
}
