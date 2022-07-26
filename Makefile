.PHONY: hoogle build-all format lint requires_nix_shell services \
		stop-services

build-all:
	nix -L --show-trace build .#packages.x86_64-linux

hoogle: requires_nix_shell
	hoogle server --local --port=8070 > /dev/null &

services: requires_nix_shell
	@cd testnet; ./start-node.sh > node.log & \
	sleep 0.5; \
	echo "Waiting for node.socket, please wait...."; \
	until [ -S $$PWD/node/node.socket ]; do sleep 1; done; \
	./start-cix.sh > cix.log &

stop-services: requires_nix_shell
	pkill -SIGINT cardano-node; pkill -SIGINT plutus-chain-in

serve: requires_nix_shell
	@cd testnet; . ./set-env.sh && cd .. && cabal run partial-tx-server

build-frontend: requires_nix_shell
	@cd lucid-partialtx; npx webpack

watch-frontend: requires_nix_shell
	@cd lucid-partialtx; npx webpack --watch

ifdef FLAGS
GHC_FLAGS = --ghc-options "$(FLAGS)"
endif

EXTENSIONS := -o -XTypeApplications -o -XPatternSynonyms

# Run fourmolu formatter
format: requires_nix_shell
	env -C . fourmolu -i --check-idempotence $(EXTENSIONS) $(shell env -C . fd -ehs)
	nixpkgs-fmt $(NIX_SOURCES)
	cabal-fmt -i $(CABAL_SOURCES)

# Check formatting (without making changes)
format_check:
	env -C . fourmolu --mode check --check-idempotence $(EXTENSIONS) $(shell env -C . fd -ehs)
	nixpkgs-fmt --check $(NIX_SOURCES)
	cabal-fmt -c $(CABAL_SOURCES)

# Nix files to format
NIX_SOURCES := $(shell fd -enix)
CABAL_SOURCES := $(shell fd -ecabal)

nixfmt: requires_nix_shell
	nixfmt $(NIX_SOURCES)

nixfmt_check: requires_nix_shell
	nixfmt --check $(NIX_SOURCES)

# Apply hlint suggestions
lint: requires_nix_shell
	find -name '*.hs' -not -path './dist-*/*' -exec hlint --refactor --refactor-options="--inplace" {} \;

# Check hlint suggestions
lint_check: requires_nix_shell
	hlint $(shell fd -ehs)

# Target to use as dependency to fail if not inside nix-shell
requires_nix_shell:
	@ [ "$(IN_NIX_SHELL)" ] || echo "The $(MAKECMDGOALS) target must be run from inside a nix shell"
	@ [ "$(IN_NIX_SHELL)" ] || (echo "    run 'nix develop' first" && false)
