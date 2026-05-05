#!/usr/bin/env bash
set -euo pipefail

VERSION="${1:-}"
if [[ -z "$VERSION" ]]; then
  echo "Usage: $0 <version>" >&2
  echo "Example: $0 2026-05-05" >&2
  exit 1
fi

REPO="sleey/japan-dict"
ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
SENSEI_REPO="${SENSEI_REPO:-$ROOT_DIR/../sensei}"
OUT_DIR="$ROOT_DIR/dist/$VERSION"
ZIP_NAME="wakaru-dictionary.zip"
METADATA_NAME="latest.json"
ZIP_PATH="$OUT_DIR/$ZIP_NAME"
METADATA_PATH="$OUT_DIR/$METADATA_NAME"
PACKAGE_URL="https://github.com/$REPO/releases/latest/download/$ZIP_NAME"
TAG="dict-$VERSION"

mkdir -p "$OUT_DIR"

if [[ ! -x "$SENSEI_REPO/gradlew" ]]; then
  echo "Could not find Sensei Gradle wrapper at $SENSEI_REPO/gradlew" >&2
  echo "Set SENSEI_REPO=/path/to/sensei and retry." >&2
  exit 1
fi

(
  cd "$SENSEI_REPO"
  ./gradlew --no-configuration-cache :shared:generateDictionaryBundle \
    -Pdictionary.version="$VERSION" \
    -Pdictionary.packageUrl="$PACKAGE_URL" \
    -Pdictionary.output="$ZIP_PATH" \
    -Pdictionary.metadataOutput="$METADATA_PATH"
)

cat > "$OUT_DIR/release-notes.md" <<NOTES
Prepared Wakaru/Sensei offline Japanese dictionary.

- Version: $VERSION
- Metadata: $METADATA_NAME
- Package: $ZIP_NAME

Derived from JMdict and KANJIDIC2. See repository attribution.
NOTES

if gh release view "$TAG" --repo "$REPO" >/dev/null 2>&1; then
  gh release upload "$TAG" "$METADATA_PATH" "$ZIP_PATH" \
    --repo "$REPO" \
    --clobber
  gh release edit "$TAG" \
    --repo "$REPO" \
    --title "Dictionary $VERSION" \
    --notes-file "$OUT_DIR/release-notes.md" \
    --latest
else
  gh release create "$TAG" "$METADATA_PATH" "$ZIP_PATH" \
    --repo "$REPO" \
    --title "Dictionary $VERSION" \
    --notes-file "$OUT_DIR/release-notes.md" \
    --latest
fi

echo "Published $TAG"
echo "Metadata URL: https://github.com/$REPO/releases/latest/download/$METADATA_NAME"
echo "Package URL:  $PACKAGE_URL"
