with import <nixpkgs> {};
let gems = bundlerEnv {
      name = "cuke-gems";
      groups = [ "default" "production" "development" "test" ];
      gemdir = ./.;
    };
    age = pkgs.buildGoModule rec {
      pname = "age";
      version = "1.0.0-rc.3";
      vendorSha256 = "sha256-sXUbfxhPmJXO+KgV/dmWmsyV49Pb6CoJLbt50yVgEvI=";
      
      src = fetchFromGitHub {
        owner = "FiloSottile";
        repo = "age";
        rev = "v${version}";
        sha256 = "sha256-YXdCTK9/eMvcHWg7gQQiPlLWYx2OjbOJDDNdSYO09HU=";
      };
    };
in mkShell {
  packages = [  gems gems.wrappedRuby
    bundix age pkgs.entr ];
  shellHook = ''
    run_watch() {
      find . -type f | entr cucumber --publish-quiet -i;
    }
  '';

}
