{ stdenv
, git
, ruby
, age ? (callPackage ./age.nix {})
, callPackage}:
stdenv.mkDerivation {
  name = "moss";
  src = ./.;
  buildInputs = [ age git ruby ];
  installPhase = ''
    make install prefix=$out
  '';
}
