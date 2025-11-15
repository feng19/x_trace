
release:
	xtrace maintenance uninstall -f
	mix assets.deploy
	BURRITO_TARGET=macos_aarch64 MIX_ENV=prod mix release --force --overwrite
	cp burrito_out/xtrace_macos_aarch64 ~/.local/bin/xtrace