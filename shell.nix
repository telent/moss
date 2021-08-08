with import <nixpkgs> {};
let gems = bundlerEnv {
      name = "cuke-gems";
      gemdir = ./.;
    };
in mkShell {
  packages = [ gems gems.wrappedRuby pkgs.age pkgs.entr ];
  shellHook = ''
    run_watch() {
      find . -type f | entr cucumber --publish-quiet -i;
    }
  '';

}
