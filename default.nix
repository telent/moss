{ stdenv
, callPackage}:
let age =  callPackage ./age.nix {};
in stdenv.mkDerivation {
  name = "moss";
  src = ./.;
  buildInputs = [ age ];
  installPhase = ''
    make install prefix=$out
  '';
}
