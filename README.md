MOSS - command-line password manager using age-encryption

* PGP is "Pretty Good Privacy"
* AGE is "Actuallty Good Encryption"
* MOSS is the Maybe OK Secret Store

Yes, it's yet another pass-like program using age instead of GPG,
because it seemed like less effort to write one than to understand the
uses and limitations of anyone else's. I am not a security
professional, so the best offer I can make for its abilities is that
it *may* be OK

* moss.rb is a standalone Ruby file that uses nothing but stdlib

* The scenarios in features/moss.feature should illustrate what it does:
add, generate, edit, show a password, search password names.

* the Gemfile is needed for installing Cucumber

* the gemset.nix and shell.nix are for Nix users. If you need to edit
the Gemfile, use `nix-shell bundix --run "bundle lock && bundix"` to
regenerate gemset.nix

* if you have `entr` installed, you can get fast test feedback by doing
`find . -type f | entr cucumber --publish-quiet -i`. For Nix users,
there is an alias `run_watch` that does this
