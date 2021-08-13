# age 1.0.0-rc.3 is required for encrypted identities. If your nixpkgs
# is too old to have it, you can run
# nix-env -i `nix-instantiate -E '(import <nixpkgs> {}).callPackage ./age.nix {}'`
# to install it from this file.


{ buildGoModule
, fetchFromGitHub }:
buildGoModule rec {
  pname = "age";
  version = "1.0.0-rc.3";
  vendorSha256 = "sha256-sXUbfxhPmJXO+KgV/dmWmsyV49Pb6CoJLbt50yVgEvI=";

  src = fetchFromGitHub {
    owner = "FiloSottile";
    repo = "age";
    rev = "v${version}";
    sha256 = "sha256-YXdCTK9/eMvcHWg7gQQiPlLWYx2OjbOJDDNdSYO09HU=";
  };
}
