{ stdenv
, git
, callPackage}:
let age =  callPackage ./age.nix {};
in stdenv.mkDerivation {
  name = "moss";
  src = ./.;
  buildInputs = [ age git ];
  installPhase = ''
    make install prefix=$out
  '';
}
