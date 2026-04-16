#!/usr/bin/env bash
set -euo pipefail

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
cd "$repo_root"

pkgbuild="PKGBUILD"
bucket="https://storage.googleapis.com/claude-code-dist-86c565f3-f756-42ad-8dfa-d59b1c096819/claude-code-releases"

tmpdir="$(mktemp -d)"
trap 'rm -rf "$tmpdir"' EXIT

need() {
  command -v "$1" >/dev/null 2>&1 || {
    echo "Missing dependency: $1" >&2
    exit 1
  }
}

need curl
need jq
need sha256sum
need awk
need python3
need makepkg

github_headers=(
  -H "Accept: application/vnd.github+json"
  -H "X-GitHub-Api-Version: 2026-03-10"
)

if [[ -n "${GITHUB_TOKEN:-}" ]]; then
  github_headers+=(-H "Authorization: Bearer ${GITHUB_TOKEN}")
fi

latest_tag="$(
  curl -fsSL "${github_headers[@]}" \
    "https://api.github.com/repos/anthropics/claude-code/releases/latest" \
  | jq -r '.tag_name // empty'
)"

if [[ -z "${latest_tag:-}" ]]; then
  echo "Could not determine latest release tag" >&2
  exit 1
fi

latest_ver="${latest_tag#v}"

if [[ ! "$latest_ver" =~ ^[0-9]+([.][0-9]+)*$ ]]; then
  echo "Unexpected release tag: $latest_tag" >&2
  exit 1
fi

current_ver="$(
  awk -F= '/^pkgver=/{gsub(/^[ \t]+|[ \t]+$/, "", $2); print $2}' "$pkgbuild"
)"

echo "Current version: $current_ver"
echo "Latest version:  $latest_ver"

if [[ "$current_ver" == "$latest_ver" ]]; then
  echo "Already up to date."
  exit 0
fi

x86_url="${bucket}/${latest_ver}/linux-x64/claude"
arm_url="${bucket}/${latest_ver}/linux-arm64/claude"
license_url="https://raw.githubusercontent.com/anthropics/claude-code/v${latest_ver}/LICENSE.md"

x86_file="${tmpdir}/claude-${latest_ver}-x86_64"
arm_file="${tmpdir}/claude-${latest_ver}-aarch64"
license_file="${tmpdir}/claude-code-LICENSE-${latest_ver}.md"

echo "Downloading x86_64 binary..."
curl -fL --retry 3 --retry-all-errors -o "$x86_file" "$x86_url"

echo "Downloading aarch64 binary..."
curl -fL --retry 3 --retry-all-errors -o "$arm_file" "$arm_url"

echo "Downloading license..."
curl -fL --retry 3 --retry-all-errors -o "$license_file" "$license_url"

x86_sha="$(sha256sum "$x86_file" | awk '{print $1}')"
arm_sha="$(sha256sum "$arm_file" | awk '{print $1}')"
license_sha="$(sha256sum "$license_file" | awk '{print $1}')"

echo "x86_64 sha256:  $x86_sha"
echo "aarch64 sha256: $arm_sha"
echo "license sha256: $license_sha"

python3 - "$pkgbuild" "$latest_ver" "$license_sha" "$x86_sha" "$arm_sha" << 'PY'
import re
import sys
from pathlib import Path

pkgbuild, ver, license_sha, x86_sha, arm_sha = sys.argv[1:]
text = Path(pkgbuild).read_text()

text = re.sub(r'^pkgver=.*$', f'pkgver={ver}', text, flags=re.M)
text = re.sub(r'^pkgrel=.*$', 'pkgrel=1', text, flags=re.M)

text = re.sub(
    r"^sha256sums=\('.*?'\)$",
    f"sha256sums=('{license_sha}')",
    text,
    flags=re.M,
)
text = re.sub(
    r"^sha256sums_x86_64=\('.*?'\)$",
    f"sha256sums_x86_64=('{x86_sha}')",
    text,
    flags=re.M,
)
text = re.sub(
    r"^sha256sums_aarch64=\('.*?'\)$",
    f"sha256sums_aarch64=('{arm_sha}')",
    text,
    flags=re.M,
)

Path(pkgbuild).write_text(text)
PY

makepkg --printsrcinfo > .SRCINFO

echo
echo "Updated PKGBUILD and .SRCINFO to ${latest_ver}"
