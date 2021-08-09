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

## Setup

moss needs you to create an age identity that it will use to decrypt
your secrets. You can choose to protect this key with a passphrase, if
you have age 1.0.0-rc3 or later

	$ age-keygen | age -p > key.age  # password-protected key
	$ age-keygen > key.age           # key with no password (if you have FDE)

	$ moss init key.age

	$ moss git init                  # if you want to share it with other machines
    $ moss git remote add me@githost.example.com:/home/git/passwords

## Storing a secret

    $ echo 'supersekritpw' | moss add folder/secretname
	[main 42f9587] new secret
	1 file changed, 7 insertions(+)
	create mode 100644 folder/secretname.age

If the store directory is managed by Git, `moss add` will add and
commit the new or changed secret to version control

## Showing a secret

    $ moss cat folder/secretname
    supersekritpw

## Listing or searching for secrets

    $ moss list folder
    folder/secretname

## Sharing the secret store

By default, moss will encrypt secrets using the public key associated
with the identity you supply.

* You can change this, or add keys, by editing the `.recipients` file
in the store directory

* You can have different keys in different subtrees of the store by
creating `.recipients` files in those subtrees. The recipients file in
a subdirectory *overrides* the recipients in a parent directory - it
is not additive

* you can run Git commands on the store using `moss git` - so use
e.g. `moss git push origin` to push to a previously configured git
remote

To find your store directory, run `moss config`


## Development

### Prerequisites

moss is written in Ruby using only the standard library (no gems).
The test suite requires Cucumber and Rspec.

On Nix, run `nix-shell` to download everything you need.  On other
Unixlikes, you will need to install Ruby and run `bundle install` to
get cucumber and rspec gems


### Running tests

The scenarios in `features/moss.feature` should illustrate what it
does: add, generate, edit, show a password, search password names,
etc.  Run `cucumber`, or if you have `entr` installed, you can use it
to rerun tests whenever something changes.

    make watch

If you need to edit the Gemfile, use `make gemset.nix` to regenerate
`gemset.nix`


## Converting from pass

I don't suggest you do this, at least until moss is a bit more mature.  I am
only writing this down because I figured out how to

    cd $HOME/.password-store
    for i in `find * -name \*.gpg`   ;do ( gpg -d $i | ~/src/moss/moss.rb add "${i%.*}" );done
