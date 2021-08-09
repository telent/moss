{ stdenv
, callPackage}:
let age =  callPackage ./age.nix {};
in stdenv.mkDerivation {
  name = "moss";
  buildInputs = [ age ];
  phases = ["installPhase"];
  installPhase = ''
    mkdir -p $out/bin
    cp ${./moss.rb} $out/bin/moss
  '';
}
