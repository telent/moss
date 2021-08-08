
Yes, it's yet another pass-like program using age instead of GPG,
because it seemed like less effort to write one than to understand the
uses and limitations of anyone else's

* rjpass.rb is a standalone Ruby file that uses nothing but stdlib

* The scenarios in features/rjpass.feature should illustrate what it does:
add, generate, edit, show a password, search password names.

* the Gemfile is needed for installing Cucumber

* the gemset.nix and shell.nix are for Nix users. If you need to edit
the Gemfile, use `bundle lock && nix run nixpkgs.bundix -c bundix` to
regenerate gemset.nix
