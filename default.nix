{ stdenv
, git
, ruby
, callPackage}:
let age =  callPackage ./age.nix {};
in stdenv.mkDerivation {
  name = "moss";
  src = ./.;
  buildInputs = [ age git ruby ];
  installPhase = ''
    make install prefix=$out
  '';
}
