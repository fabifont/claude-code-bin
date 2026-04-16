# claude-code-bin

AUR packaging for Anthropic Claude Code's upstream Linux binaries.

The `PKGBUILD` is intentionally static. `makepkg` downloads the pinned `pkgver`
and pinned checksums only; it does not discover the latest release at build time.

Maintainer updates are handled by `./update.sh`. The script reads the latest
GitHub release, downloads the x86_64 and aarch64 upstream binaries, downloads
the release-tagged upstream `LICENSE.md`, refreshes checksums, and regenerates
`.SRCINFO`.

## Update

```sh
./update.sh
git diff -- PKGBUILD .SRCINFO
makepkg --verifysource
makepkg -f
namcap PKGBUILD
namcap claude-code-bin-*.pkg.tar.zst
```

## Automation

The GitHub workflow checks for upstream releases every five minutes. When a new
release is found, it updates `PKGBUILD`, regenerates `.SRCINFO`, validates the
package, publishes `PKGBUILD` and `.SRCINFO` to AUR, and then pushes the update
commit back to GitHub.

Publishing to AUR requires a repository secret named `AUR_SSH_PRIVATE_KEY`. The
matching public key must be added to the AUR account that maintains
`claude-code-bin`.

Packaging files in this repository are licensed under 0BSD. Claude Code itself
is distributed under Anthropic's terms, referenced by the license file installed
to `/usr/share/licenses/claude-code-bin/LICENSE`.
