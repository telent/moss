MOSS - command-line password manager using age

Yes, it's yet another [pass](https://www.passwordstore.org/pass)-like
program that uses [age](https://github.com/FiloSottile/age) instead of
GPG, because it seemed like less effort to write one than to
understand the uses and limitations of anyone else's. I am not a
security professional, so the best offer I can make for its abilities
is that it *may* be OK. Hence the name "Maybe OK Secret Store"; c.f.
"Pretty Good Privacy", "Actually Good Encryption"

## Installation

    make install               # defaults to /usr/local/bin

or

    nix-env -i -f release.nix  # for Nix users

`moss.rb` is a standalone Ruby file, so if neither of these approaches fits your needs, you could just copy it to anywhere on your search path

## Setup

moss needs you to create an age identity that it will use to decrypt
your secrets. You can choose to protect this key with a passphrase, if
you have age 1.0.0-rc3 or later

    $ age-keygen | age -p > key.age  # password-protected key
    $ age-keygen > key.age           # key with no password (if you have FDE)

    $ moss init key.age

    $ moss git init                  # if you want to share it with other machines
    $ moss git remote add me@githost.example.com:/home/git/passwords

moss keeps its secrets in 

* `$MOSS_HOME/store`, if the MOSS_HOME environemt variable exists, or
* `$XDG_DATA_HOME/moss/store`, if the XDG_DATA_HOME environment variable exists, or
* `$HOME/.local/share/moss/store` : $HOME is assumed to exist


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
with the identity you supplied when you ran `moss init`

* You can change the key, or add keys, by editing the `.recipients`
file in the store directory. This is an age recipient file, so may
contain "one or more recipients, one per line. Empty lines and lines
starting with "#" are ignored as comments."

* You can have different keys in different subtrees of the store by
creating `.recipients` files in those subtrees. The recipients file in
a subdirectory *overrides* the recipients in a parent directory - it
is not additive

* you can run [Git](https://git-scm.com/) commands on the store using
`moss git` - so use e.g. `moss git push origin` to push to a
previously configured git remote

To find your store directory, run `moss config`


## Development

### Prerequisites

moss is written in Ruby using only the standard library (no gems).
The test suite requires
[Cucumber](https://cucumber.io/docs/installation/ruby/) and [Rspec](https://rspec.info/).

On Nix, run `nix-shell` to download everything you need.  On other
Unixlikes, you will need to install Ruby and run `bundle install` to
get cucumber and rspec gems


### Running tests

The scenarios in [features/moss.feature](features/moss.feature) should
illustrate what it does: add, generate, edit, show a password, search
password names, etc.  Run `cucumber`, or if you have `entr` installed,
you can use it to rerun tests whenever something changes.

    make watch

If you need to edit the Gemfile, use `make gemset.nix` to regenerate
`gemset.nix`


## Converting from pass

I don't suggest you do this, at least until moss is a bit more mature.  I am
only writing this down because I figured out how to

    cd $HOME/.password-store
    for i in `find * -name \*.gpg`   ;do ( gpg -d $i | ~/src/moss/moss.rb add "${i%.*}" );done

## TO DO

* remove secrets
* copy to clipboard
* check before overwriting secrets that exist already
* support re-encrypting a subtree when recipients change
* --help option
* warn or fail if iffy store permissions?

