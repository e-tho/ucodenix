#!/usr/bin/env bash

set -euo pipefail

OUTPUT=$(nix run nixpkgs#nix-prefetch-git -- --quiet https://github.com/platomav/CPUMicrocodes --rev refs/heads/master)
REV=$(echo "$OUTPUT" | nix run nixpkgs#jq -- -r .rev)
SHORT_REV=$(echo "$REV" | cut -c1-7)
echo "Fetched rev: $REV (short: $SHORT_REV)"

echo "rev=$REV" >> $GITHUB_ENV
echo "shortRev=$SHORT_REV" >> $GITHUB_ENV

if ! grep -q "url = \"github:platomav/CPUMicrocodes/$REV\";" flake.nix; then
  echo "Updating flake input to rev: $REV"
  sed -i 's|url = "github:platomav/CPUMicrocodes/.*";|url = "github:platomav/CPUMicrocodes/'"$REV"'";|' flake.nix

  git add flake.nix
  git commit -m "Update CPUMicrocodes flake input"
  echo "Commit created for new input revision."
else
  echo "No changes to commit. Already up to date with rev: $REV"
fi
