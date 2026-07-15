#!/usr/bin/env bash
# Build a clean, up-to-date distribution of the xmlit package in
# dist/xmlit/<version>/ — the folder that gets copied into the
# typst/packages repository (under packages/preview/) to publish
# @preview/xmlit. To import the vendored package locally, point
# TYPST_PACKAGE_PATH at a directory whose `preview/` entry links to dist/
# (see the validation step below).
#
# Usage:
#   ./make_dist.sh --tag=<TAG>   e.g. ./make_dist.sh --tag=v0.1.0
#   ./make_dist.sh --no-tag
#
# Steps:
#   1. build the RELAX NG WASM plugin (plugin/build.sh) so the vendored
#      src/relaxng/relaxng.wasm is up to date
#   2. run the test suite (tests/run.sh: unit tests + expected-failure probes)
#   3. assemble the package (typst.toml, LICENSE, README.md, src/ — no
#      tests/, plugin/, or *.test.typ files, matching `exclude` in
#      typst.toml); the README's relative links (which only work when
#      browsing this repo on GitHub) are rewritten to absolute permalinks
#      against `repository` in typst.toml, pinned at --tag/--no-tag (see
#      below), so the published README is portable to Typst Universe /
#      typst/packages
#   4. compile the tytanic test suite (imports rewritten to
#      `@preview/xmlit:<version>` in a scratch copy — tests aren't part of
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

echo "==> Building the RELAX NG WASM plugin"
plugin/build.sh

echo "==> Running tests"
# tests/run.sh compiles the unit tests and checks the expected-failure probes.
./tests/run.sh

echo "==> Assembling $PKG/"
rm -rf dist
mkdir -p "$PKG"
cp typst.toml LICENSE "$PKG/"
# The published README keeps user documentation only: strip the Development
# section (everything from "## Development" up to the next "## " heading,
# i.e. the rest of the file), drop the now-dangling link to it, and rewrite
# repo-relative links so the README is portable outside GitHub — markdown
# links `](path)` become blob links (or tree links for directory paths
# ending in `/`). Absolute (`http...`), anchor (`#...`), and `mailto:`
# targets are left untouched.
awk '/^## Development$/ { skip = 1; next } skip && /^## / { skip = 0 } !skip' \
    README.md \
    | grep -v 'See \[Development\](#development)' \
    | BLOB_BASE="$BLOB_BASE" TREE_BASE="$TREE_BASE" perl -pe '
        s{\]\(([^)]+)\)}{
            my $p = $1;
            $p =~ m{^(?:https?:|#|mailto:)} ? "](" . $p . ")"
            : $p =~ m{/$} ? "](" . $ENV{TREE_BASE} . "/" . $p . ")"
            : "](" . $ENV{BLOB_BASE} . "/" . $p . ")"
        }ge;
    ' >"$PKG/README.md"
mkdir -p "$PKG/src"
(cd src && find . -type f ! -name '*.test.typ') | while IFS= read -r f; do
    mkdir -p "$PKG/src/$(dirname "$f")"
    cp "src/$f" "$PKG/src/$f"
done

echo "==> Validating the vendored package as @preview/xmlit:$VERSION"
# Typst resolves `@preview/...` from `$TYPST_PACKAGE_PATH/preview/...`, so
# expose dist/ under a `preview` symlink and compile the test suite against
# it — exactly how users will consume the package. The tests aren't part of
# the published package (see step 3); a scratch copy of tests/ with the
# import rewritten to `@preview/xmlit:<version>` is used here only for
# validation, keeping the original tree (and its relative fixture reads,
# e.g. tests/xml-to-string/fixture.xml) intact.
pkgroot=$(mktemp -d)
validation_root=$(mktemp -d)
trap 'rm -rf "$pkgroot" "$validation_root"' EXIT
ln -s "$PWD/dist" "$pkgroot/preview"
cp -r tests "$validation_root/tests"
find "$validation_root/tests" -name test.typ -exec sed -i \
    "s|#import \"/src/lib.typ\"|#import \"@preview/xmlit:$VERSION\"|" {} +
for f in "$validation_root"/tests/*/test.typ; do
    TYPST_PACKAGE_PATH="$pkgroot" typst compile --root "$validation_root" -f pdf "$f" /dev/null
done

echo "==> Done: $PKG/ ($(du -sh dist | cut -f1))"
find dist -type f | sort
