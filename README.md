# claude-code-bin

Temporary AUR automation testbed for Claude Code packaging.

This repository currently keeps the `claude-code-bin` package identity so the
automation can be tested without touching the existing `claude-code` AUR package.
The packaging model otherwise follows the current `claude-code` package:

- upstream binaries are downloaded from `https://downloads.claude.ai`
- architecture checksums come from the upstream `manifest.json`
- the legal/compliance document is installed as the package license
- the binary is installed under `/opt/claude-code/bin/claude`
- `/usr/bin/claude` is a small wrapper that disables the upstream auto-updater

## Update

Use `pkgctl version check` to detect whether upstream has a newer release, then
run `update-version.sh` to update pinned package metadata:

```sh
pkgctl version check
./update-version.sh
git diff -- PKGBUILD .SRCINFO
```

`update-version.sh` reads the upstream `latest` file, downloads
`manifest.json`, updates `pkgver`, resets `pkgrel`, refreshes the
architecture-specific checksums, and regenerates `.SRCINFO`.

## Validate

```sh
shellcheck --shell=bash --exclude=SC2034,SC2154,SC2164 PKGBUILD update-version.sh
actionlint .github/workflows/update.yml
cmp .SRCINFO <(makepkg --printsrcinfo)
makepkg --verifysource
env CARCH=aarch64 makepkg --verifysource
makepkg -f
namcap PKGBUILD
namcap claude-code-bin-*.pkg.tar.zst
```

## Automation

The GitHub workflow has two paths:

- `push`: validate and publish the current package files to AUR. This allows
  manual PKGBUILD or script changes without forcing a version bump.
- `schedule` / `workflow_dispatch`: run `pkgctl version check`; when upstream is
  newer, run `update-version.sh`, validate, commit the generated package update,
  push it to GitHub, and publish to AUR.

Publishing to AUR requires repository secrets named `AUR_SSH_PRIVATE_KEY` and,
if the key is encrypted, `AUR_SSH_PASSPHRASE`. The matching public key must be
added to the AUR account that maintains the package.

### External Dispatcher

GitHub's scheduled workflows are best-effort. If you want an additional trigger
from a server you control, copy `.env.example` to `.env`, set `GITHUB_PAT` to a
fine-grained token with Actions write access to this repository, and run:

```sh
docker compose up -d
```

The dispatcher calls the workflow's `workflow_dispatch` endpoint every five
minutes. It only starts the GitHub workflow; package validation and AUR
publishing still happen in GitHub Actions.

## Migration to claude-code

Once this is accepted for the existing `claude-code` package, the expected
cleanup is:

- change `pkgname` from `claude-code-bin` to `claude-code`
- remove `provides` and `conflicts`
- change the `.nvchecker.toml` section to `[claude-code]`
- change `AUR_PKGBASE` in the workflow to `claude-code`
- update `.env.example` and `docker-compose.yml` defaults from
  `claude-code-bin` to the target GitHub repository name if the repository is
  renamed
- update validation commands and package globs from `claude-code-bin` to
  `claude-code`

Packaging files in this repository are licensed under 0BSD. Claude Code itself
is distributed under Anthropic's terms, referenced by the license file installed
to `/usr/share/licenses/claude-code-bin/LICENSE`.
