with import <nixpkgs> {};
let gems = bundlerEnv {
      name = "cuke-gems";
      groups = [ "default" "production" "development" "test" ];
      gemdir = ./.;
    };
    age = pkgs.callPackage ./age.nix {};
in mkShell {
  MOSS_HOME = "/tmp/${builtins.getEnv "USER"}/moss_home";
  CUCUMBER_PUBLISH_QUIET = "true";
  packages = [
    gems gems.wrappedRuby
    pkgs.expect
    bundix age pkgs.entr
  ];
}
