NIX := nix
CC :- $(NIX) build -L --show-trace

depot-tools:
	$(CC) ".#depot-tools"

check:
	$(NIX) flake check --keep-going

info:
	$(NIX) flake show
