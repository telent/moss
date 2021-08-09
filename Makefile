default: moss.rb

install: default
	mkdir -p $(prefix)/bin
	cp moss.rb $(prefix)/bin/moss

gemset.nix: Gemfile
	nix-shell -p bundler -p bundix --run "bundle lock && bundix"

watch:
	find . -type f | entr cucumber --publish-quiet -i
