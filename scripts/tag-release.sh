#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
./scripts/version.py validate
release_tag="$(./scripts/version.py tag)"
if [ -n "$(git status --porcelain)" ]; then
  printf 'Commit all tracked and untracked changes before tagging a release.\n' >&2
  exit 1
fi
if git show-ref --verify --quiet "refs/tags/$release_tag" || [ -n "$(git ls-remote --tags origin "refs/tags/$release_tag")" ]; then
  printf 'Tag %s already exists. Bump and commit the version before the next release.\n' "$release_tag" >&2
  exit 1
fi
./scripts/test-version.py
./scripts/test.sh
git tag -a "$release_tag" -m "MacClean $release_tag"
git push origin "refs/tags/$release_tag"
printf 'Pushed %s. GitHub Actions will test, package, and publish a prerelease.\n' "$release_tag"
