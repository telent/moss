MOSS - command-line password manager using age-encryption

* PGP is "Pretty Good Privacy"
* AGE is "Actually Good Encryption"
* MOSS is the "Maybe OK Secret Store"

Yes, it's yet another pass-like program using age instead of GPG,
because it seemed like less effort to write one than to understand the
uses and limitations of anyone else's. I am not a security
professional, so the best offer I can make for its abilities is that
it *may* be OK

## Installation

`moss.rb` is a standalone Ruby file. You can `make install` or just copy it to somewhere on your PATH

Or if you are a Nix user, you can run

    nix-env -i -f release.nix

## Development

### Prerequisites

On Nix, run `nix-shell`

On other Unixlikes, you will need to install Ruby and run `bundle
install` to get cucumber and rspec

### Running tests

The scenarios in `features/moss.feature` should illustrate what it
does: add, generate, edit, show a password, search password names.
Run `cucumber`, or if you have `entr` installed, you can use it to
rerun tests whenever something changes.

    make watch

If you need to edit the Gemfile, use `make gemset.nix` to regenerate
`gemset.nix`


## Converting from pass

I don't suggest you do this, at least until moss is a bit more mature.  I am
only writing this down because I figured out how to

    cd $HOME/.password-store
    for i in `find * -name \*.gpg`   ;do ( gpg -d $i | ~/src/moss/moss.rb add "${i%.*}" );done
