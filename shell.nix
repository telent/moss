with import <nixpkgs> {};
let gems = bundlerEnv {
      name = "cuke-gems";
      groups = [ "default" "production" "development" "test" ];
      gemdir = ./.;
    };
    age = pkgs.callPackage ./age.nix {};
in mkShell {
  packages = [
    gems gems.wrappedRuby
    bundix age pkgs.entr
  ];
  shellHook = ''
    run_watch() {
      find . -type f | entr cucumber --publish-quiet -i;
    }
  '';
}
