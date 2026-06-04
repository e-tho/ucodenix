{
  stdenv,
  libarchive,
  ucodenix,
}:
stdenv.mkDerivation {
  name = "amd-ucode";
  src = ucodenix;

  nativeBuildInputs = [ libarchive ];

  installPhase = ''
    mkdir -p $out
    touch -d @$SOURCE_DATE_EPOCH kernel/x86/microcode/AuthenticAMD.bin
    echo kernel/x86/microcode/AuthenticAMD.bin | bsdtar --uid 0 --gid 0 -cnf - -T - | bsdtar --null -cf - --format=newc @- > $out/amd-ucode.img
  '';
}
