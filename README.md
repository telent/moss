MOSS - command-line password manager using age

Yes, it's yet another [pass](https://www.passwordstore.org/pass)-like
program that uses [age](https://github.com/FiloSottile/age) instead of
GPG, because it seemed like less effort to write one than to
understand the uses and limitations of anyone else's. I am not a
security professional, so the best offer I can make for its abilities
is that it *may* be OK. Hence the name "Maybe OK Secret Store"; c.f.
"Pretty Good Privacy", "Actually Good Encryption"

Status: pre-alpha, i don't use it for anything important yet and I
don't think you should either.

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
    for i in `find * -name \*.gpg`   ;do ( gpg -d $i | moss add "${i%.*}" );done

## Security considerations

Read this section with the caveat that this program has not been
reviewed by a security professional. I welcome feedback on any of the
points here, or on any other points that aren't here but should be.

The primary consideration with regard to threat modelling is that
moss encrypts and decrypts files using age, in much the same way as
you might otherwise invoke age by hand. If this doesn't fit your
security requirements, look elsewhere.

* secrets stored in moss depend on the security guarantees provided by
  age. age is written by Filippo Valsorda, who is a real
  cryptographer, so this is probably not the part you should be most
  worried about

* moss expects that your `$MOSS_HOME` is kept on a local filesystem,
  or at least that the file server is trusted and traffic to it can't
  be tampered with. Secrets are not signed, so (I think) you cannot
  detect when an attacker substitutes a secret other than the one you
  asked for.

* if an attacker can read files on your computer, but you have
  encrypted the private key, security of your secrets depends on the
  strength of your passphrase and on their being no relevant bugs in age.
  moss does not store or see your passphrase in this scenario: it runs
  age as a subprocess which opens `/dev/tty` directly.

* if an attacker can read files on your computer and you have not
  encrypted your private key, security of your secrets depends on
  whether you are using an encrypted filesystem, the quality of that
  filesystem and/or whether the attacker can gain access to it while
  it's mounted. I believe that most Linux systems won't unmount it
  while the screen is locked, for one.

* if an attacker can write files in your store, they can wipe out your
  secrets or replace them with other ones, and you might not notice
  (until you try using them, anyway) because secrets are not signed

* if you have any of: insecure buggy virtual keyboards, keystroke
  loggers, cameras pointing at your keyboard, virtual hosts with
  compromised hypervisors, then moss won't help you

* `pass edit` uses Ruby's Tempfile class to write a temporary
  plaintext file containing the secret. According to the Ruby
  documentation the "filename picking method is both thread-safe and
  inter-process-safe", so can be relied on to be race-free. It creates
  the file mode 0600. The file is deleted after the editor exits, but
  will not be cleaned up if the moss process is killed while the
  editor is running,

* all cryptographic operations are performed by running `age` in a
  subprocess. Care has been taken to ensure it uses arrays instead
  of interpolating values into strings which may give rise to shell
  shell injection attacks

* the first time an encrypted identity is needed (i.e when reading a
  secret), we create a temporary file using Tempfile, and unlink it
  before running age to decrypt the secret into it.  This is so that
  `moss rebuild` prompts only once for the passphrase instead of once
  per secret. moss does not read the decrypted file itself.

* reasonable care has been taken to set appropriate file permissions
  on keys and secrets, so you should be good against other non-root
  users on your machine


## TO DO

* copy to clipboard
* warn or fail if iffy store permissions?
