#!/usr/bin/env bash

set -euo pipefail

nix flake update cpu-microcodes
NODE_NAME=$(nix run nixpkgs#jq -- -r '.nodes.root.inputs."cpu-microcodes"' flake.lock)
REV=$(nix run nixpkgs#jq -- -r ".nodes.\"$NODE_NAME\".locked.rev" flake.lock)
SHORT_REV=$(echo "$REV" | cut -c1-7)
echo "rev: $REV (short: $SHORT_REV)"

echo "rev=$REV" >> $GITHUB_ENV
echo "shortRev=$SHORT_REV" >> $GITHUB_ENV

if ! git diff --quiet; then
  echo "Updating flake input to rev: $REV"
  git add flake.lock
  git commit -m "Update CPUMicrocodes flake input"
  echo "Commit created for new input revision."
else
  echo "No changes to commit. Already up to date with rev: $REV"
fi
