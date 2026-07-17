#!/usr/bin/env bash
# Build a clean, up-to-date distribution of the xmlit package in
# dist/xmlit/<version>/ — the folder that gets copied into the
# typst/packages repository (under packages/preview/) to publish it on Typst
# Universe as @preview/xmlit. Before it's published there, the vendored
# package is validated locally under the @local namespace (the one Typst
# reserves for unpublished packages): point TYPST_PACKAGE_PATH at a directory
# whose `local/` entry links to dist/ and import it as @local/xmlit (see the
# validation step below).
#
# Usage:
#   ./make_dist.sh --tag=<TAG>   e.g. ./make_dist.sh --tag=v0.1.0
#   ./make_dist.sh --no-tag
#
# Steps:
#   1. build the RELAX NG WASM plugin (plugin/build.sh) so the vendored
#      src/relaxng/relaxng.wasm is up to date
#   2. run the test suite (tests/run.sh: unit tests + expected-failure probes
#      + example compilation)
#   3. render the showcase example(s) to committed PNGs the README embeds
#      (examples/images/*.png)
#   4. assemble the package (typst.toml, LICENSE, README.md, src/ — no
#      tests/, plugin/, or *.test.typ files, matching `exclude` in
#      typst.toml); the README's relative links (which only work when
#      browsing this repo on GitHub) are rewritten to absolute permalinks
#      against `repository` in typst.toml, pinned at --tag/--no-tag (see
#      below), so the published README is portable to Typst Universe /
#      typst/packages
#   5. compile the tytanic test suite (imports rewritten to
#      `@local/xmlit:<version>` in a scratch copy — tests aren't part of
#      the published package) against the vendored package, to validate it
#      works as advertised
set -euo pipefail
cd "$(dirname "$0")"

usage() {
    cat >&2 <<'EOF'
usage: ./make_dist.sh (--tag=<TAG> | --no-tag)

This script rewrites README.md's repo-relative links (e.g. to plugin/) into
absolute GitHub permalinks, since the published package does not ship the
plugin/ or tests/ directories themselves. A permalink must be pinned to
something — a release tag or a commit — so you must say which:

  --tag=<TAG>   Pin the links to the given git tag, e.g. --tag=v0.1.0. Use
                this for an actual release: create and push the tag first
                    git tag v0.1.0 && git push origin v0.1.0
                then pass that same tag here, so the published README reads
                nicely and links stay valid for that release forever.

  --no-tag      Pin the links to the current commit (git rev-parse HEAD)
                instead of a tag. Use this for a local/test build of dist/
                when you don't want to create a release tag yet.

Exactly one of these is required — there is no default, because silently
falling back to one could point a real release at an untagged commit, or
force a test build to fail for lacking a tag.
EOF
}

TAG_MODE=""
RELEASE_TAG=""
for arg in "$@"; do
    case "$arg" in
        --tag=*)
            TAG_MODE="tag"
            RELEASE_TAG="${arg#--tag=}"
            ;;
        --no-tag)
            TAG_MODE="no-tag"
            ;;
        *)
            echo "error: unknown argument '$arg'" >&2
            echo >&2
            usage
            exit 1
            ;;
    esac
done
if [ -z "$TAG_MODE" ]; then
    echo "error: --tag=<TAG> or --no-tag is required" >&2
    echo >&2
    usage
    exit 1
fi
if [ "$TAG_MODE" = "tag" ] && [ -z "$RELEASE_TAG" ]; then
    echo "error: --tag= was given an empty tag name" >&2
    echo >&2
    usage
    exit 1
fi

VERSION=$(grep -m1 '^version' typst.toml | sed 's/.*"\(.*\)"/\1/')
PKG="dist/xmlit/$VERSION"
echo "==> xmlit $VERSION"

# Base URLs for rewriting the README's repo-relative links (see step 3).
# Pinned to a permalink (a tag or a commit, never a branch name), so the
# links keep pointing at the exact files this version of the package
# shipped with — the typst/packages checker flags branch-relative links
# ("GitHub URL links to default branch") and recommends this instead.
REPO_URL=$(grep -m1 '^repository' typst.toml | sed 's/.*"\(.*\)"/\1/')
if [ "$TAG_MODE" = "tag" ]; then
    if ! git rev-parse --verify --quiet "refs/tags/$RELEASE_TAG" >/dev/null; then
        echo "error: git tag '$RELEASE_TAG' does not exist in this repository." >&2
        echo >&2
        echo "  --tag=$RELEASE_TAG was given, but that tag hasn't been created." >&2
        echo "  Create and push it first:" >&2
        echo >&2
        echo "    git tag $RELEASE_TAG" >&2
        echo "    git push origin $RELEASE_TAG" >&2
        echo >&2
        echo "  ...then re-run this script." >&2
        exit 1
    fi
    GITHUB_REF="$RELEASE_TAG"
    if [ "$(git rev-parse "$RELEASE_TAG")" != "$(git rev-parse HEAD)" ]; then
        echo "warning: tag '$RELEASE_TAG' does not point at the current commit (HEAD)." >&2
        echo "         The README will link to tag '$RELEASE_TAG', but src/ and the test" >&2
        echo "         suite used to build this dist/ come from the current working" >&2
        echo "         tree, which may not match what that tag contains." >&2
    fi
else
    GITHUB_REF=$(git rev-parse HEAD)
fi
if [ -n "$(git status --porcelain)" ]; then
    echo "warning: working tree has uncommitted changes; README links will point at" >&2
    echo "         $GITHUB_REF, which may not match what's on GitHub yet." >&2
    echo "         Commit and push before running this for a release." >&2
fi
BLOB_BASE="$REPO_URL/blob/$GITHUB_REF"
TREE_BASE="$REPO_URL/tree/$GITHUB_REF"
# Images must resolve to the actual file bytes, not GitHub's HTML "blob" viewer
# page, so <img src="..."> paths are rewritten to raw.githubusercontent.com
# (the README embeds examples/images/*.png).
RAW_BASE="https://raw.githubusercontent.com/${REPO_URL#https://github.com/}/$GITHUB_REF"

echo "==> Building the RELAX NG WASM plugin"
plugin/build.sh

echo "==> Running tests"
# tests/run.sh compiles the unit tests, checks the expected-failure probes, and
# compiles the examples.
./tests/run.sh

echo "==> Rendering example screenshots for the README"
# Render the showcase example(s) to committed PNGs the README embeds. Uses the
# plugin built above (create-from-relaxng loads the bundled WASM); the example
# is already known to compile, since the test run above compiles every
# examples/*.typ. --ppi 150 keeps text crisp on high-DPI displays without
# bloating the file. Commit the regenerated PNG alongside your other changes so
# the raw-URL rewrite below (pinned to this commit/tag) resolves once pushed.
mkdir -p examples/images
typst compile --root . -f png --ppi 150 \
    examples/create-from-relaxng.typ examples/images/create-from-relaxng.png

echo "==> Assembling $PKG/"
rm -rf dist
mkdir -p "$PKG"
cp typst.toml LICENSE "$PKG/"
# The published README keeps user documentation only: strip the Development
# section (everything from "## Development" up to the next "## " heading,
# i.e. the rest of the file), drop the now-dangling link to it, and rewrite
# repo-relative links so the README is portable outside GitHub — markdown
# links `](path)` become blob links (or tree links for directory paths
# ending in `/`), and `<img src="...">` paths become raw.githubusercontent.com
# links so the embedded screenshot loads. Absolute (`http...`), anchor
# (`#...`), and `mailto:` targets are left untouched.
awk '/^## Development$/ { skip = 1; next } skip && /^## / { skip = 0 } !skip' \
    README.md \
    | grep -v 'See \[Development\](#development)' \
    | BLOB_BASE="$BLOB_BASE" TREE_BASE="$TREE_BASE" RAW_BASE="$RAW_BASE" perl -pe '
        s{\]\(([^)]+)\)}{
            my $p = $1;
            $p =~ m{^(?:https?:|#|mailto:)} ? "](" . $p . ")"
            : $p =~ m{/$} ? "](" . $ENV{TREE_BASE} . "/" . $p . ")"
            : "](" . $ENV{BLOB_BASE} . "/" . $p . ")"
        }ge;
        s{(<img\b[^>]*\bsrc=")([^"]+)(")}{
            $2 =~ m{^https?:} ? "$1$2$3" : "$1" . $ENV{RAW_BASE} . "/$2" . "$3"
        }ge;
    ' >"$PKG/README.md"
mkdir -p "$PKG/src"
(cd src && find . -type f ! -name '*.test.typ') | while IFS= read -r f; do
    mkdir -p "$PKG/src/$(dirname "$f")"
    cp "src/$f" "$PKG/src/$f"
done

echo "==> Validating the vendored package as @local/xmlit:$VERSION"
# Typst resolves `@local/...` from `$TYPST_PACKAGE_PATH/local/...`, so expose
# dist/ under a `local` symlink and compile the test suite against it — the
# same resolution path an unpublished package uses locally. (@local, not
# @preview: @preview is the Universe registry namespace, so pointing it at a
# local dir would shadow the real registry and misrepresent how the package
# is consumed before release.) The tests aren't part of the published package
# (see step 3); a scratch copy of tests/ with the import rewritten to
# `@local/xmlit:<version>` is used here only for validation, keeping the
# original tree (and its relative fixture reads, e.g.
# tests/xml-to-string/fixture.xml) intact.
pkgroot=$(mktemp -d)
validation_root=$(mktemp -d)
trap 'rm -rf "$pkgroot" "$validation_root"' EXIT
ln -s "$PWD/dist" "$pkgroot/local"
cp -r tests "$validation_root/tests"
# Public-API imports (`/src/lib.typ`) are rewritten to `@local/xmlit` so the
# package's entrypoint and resolution are what gets exercised. A few tests are
# white-box: they import internal modules by absolute path (e.g.
# `/src/relaxng/relaxng.typ`) to reach helpers `lib.typ` doesn't re-export.
# Those aren't reachable through the package entrypoint, so expose the VENDORED
# src (the exact files that shipped) under the validation root for them to
# resolve against — everything the tests touch then comes from dist/.
ln -s "$PWD/$PKG/src" "$validation_root/src"
find "$validation_root/tests" -name test.typ -exec sed -i \
    "s|#import \"/src/lib.typ\"|#import \"@local/xmlit:$VERSION\"|" {} +
for f in "$validation_root"/tests/*/test.typ; do
    TYPST_PACKAGE_PATH="$pkgroot" typst compile --root "$validation_root" -f pdf "$f" /dev/null
done

echo "==> Done: $PKG/ ($(du -sh dist | cut -f1))"
find dist -type f | sort
