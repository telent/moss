default: moss.rb

AGE?=$(shell command -v age)
AGE_KEYGEN?=$(shell command -v age-keygen)
GIT?=$(shell command -v git)

install: default
	mkdir -p $(prefix)/bin
	sed < moss.rb > $(prefix)/bin/moss \
	 -e 's@^AGE=.*$$@AGE="$(AGE)"@' \
	 -e 's@^AGE_KEYGEN=.*$$@AGE_KEYGEN="$(AGE_KEYGEN)"@' \
	 -e 's@^GIT=.*$$@GIT="$(GIT)"@'
	chmod a+rx $(prefix)/bin/moss

gemset.nix: Gemfile
	nix-shell -p bundler -p bundix --run "bundle lock && bundix"

test:
	cucumber --publish-quiet -i
	rspec -I .

watch:
	find . -type f | entr $(MAKE) test
