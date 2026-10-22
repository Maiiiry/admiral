#!/usr/bin/env bash
# SPDX-License-Identifier: Apache-2.0
# Run admiralctl checks in an RPM-equivalent source layout without changing the checkout.
set -euo pipefail

root_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
expected_admirald=$(sed -n 's/^ADMIRALD_COMMIT := //p' "$root_dir/Makefile")
actual_admirald=$(git -C "$root_dir/admirald" rev-parse HEAD)

[[ -n $expected_admirald && $actual_admirald == "$expected_admirald" ]] || {
  echo "admirald checkout does not match ADMIRALD_COMMIT in the root Makefile" >&2
  exit 1
}
[[ -z $(git -C "$root_dir/admirald" status --porcelain) ]] || {
  echo "admirald has local changes; refusing to test a source tree different from its commit" >&2
  exit 1
}
[[ -z $(git -C "$root_dir/admiralctl" status --porcelain) ]] || {
  echo "admiralctl has local changes; refusing to test a source tree different from its commit" >&2
  exit 1
}

stage_dir=$(mktemp -d "${TMPDIR:-/tmp}/admiralctl-local-check.XXXXXX")
trap 'rm -rf -- "$stage_dir"' EXIT
git -C "$root_dir/admiralctl" archive --format=tar HEAD | tar -x -C "$stage_dir"
ln -s "$root_dir/admirald" "$stage_dir/admirald"

cd "$stage_dir"
export GOTOOLCHAIN=${GOTOOLCHAIN:-auto}
go mod tidy
go test ./...
go vet ./...
go build ./...
