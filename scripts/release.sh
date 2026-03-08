#!/bin/bash
set -euo pipefail

# Verba Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 0.3.0
#
# What it does:
# 1. Bumps version in project.yml
# 2. Builds Release binary
# 3. Creates signed zip
# 4. Updates appcast.xml with signature
# 5. Creates GitHub Release with zip attached
# 6. Pushes changes (appcast.xml update) to trigger GitHub Pages deploy

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SIGN_UPDATE="/tmp/sparkle-build/Build/Products/Release/sign_update"
APPCAST_FILE="$PROJECT_DIR/docs/appcast.xml"
BUILD_DIR="$PROJECT_DIR/build"

cd "$PROJECT_DIR"

# --- Version ---
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
    # Read current version from project.yml
    CURRENT=$(grep 'MARKETING_VERSION' project.yml | head -1 | sed 's/.*"\(.*\)".*/\1/')
    echo "Current version: $CURRENT"
    echo "Usage: $0 <new-version>"
    echo "Example: $0 0.3.0"
    exit 1
fi

echo "==> Releasing Verba v$VERSION"

# --- Check prerequisites ---
if [ ! -f "$SIGN_UPDATE" ]; then
    echo "ERROR: sign_update not found at $SIGN_UPDATE"
    echo "Build it first: cd <Sparkle checkout> && xcodebuild -scheme sign_update -configuration Release -derivedDataPath /tmp/sparkle-build"
    exit 1
fi

if ! command -v gh &>/dev/null; then
    echo "ERROR: gh (GitHub CLI) is required"
    exit 1
fi

if ! command -v xcodegen &>/dev/null; then
    echo "ERROR: xcodegen is required"
    exit 1
fi

# --- Bump version ---
echo "==> Bumping version to $VERSION"
sed -i '' "s/MARKETING_VERSION: \".*\"/MARKETING_VERSION: \"$VERSION\"/" project.yml

# --- Regenerate Xcode project ---
echo "==> Regenerating Xcode project"
xcodegen generate

# --- Build ---
echo "==> Building Release"
mkdir -p "$BUILD_DIR"
xcodebuild -scheme Verba -configuration Release \
    CODE_SIGN_IDENTITY="-" \
    CODE_SIGNING_REQUIRED=NO \
    CODE_SIGNING_ALLOWED=NO \
    CONFIGURATION_BUILD_DIR="$BUILD_DIR" \
    build 2>&1 | tail -5

APP_PATH="$BUILD_DIR/Verba.app"
if [ ! -d "$APP_PATH" ]; then
    echo "ERROR: Build failed — Verba.app not found"
    exit 1
fi

# --- Create zip ---
echo "==> Creating zip"
ZIP_NAME="Verba-v${VERSION}.zip"
ZIP_PATH="$BUILD_DIR/$ZIP_NAME"
cd "$BUILD_DIR"
ditto -c -k --keepParent "Verba.app" "$ZIP_NAME"
cd "$PROJECT_DIR"

# --- Sign zip ---
echo "==> Signing zip with Sparkle EdDSA"
SIGNATURE=$("$SIGN_UPDATE" "$ZIP_PATH" 2>&1)
# Parse: sparkle:edSignature="..." length="..."
ED_SIGNATURE=$(echo "$SIGNATURE" | grep -o 'sparkle:edSignature="[^"]*"' | sed 's/sparkle:edSignature="//;s/"//')
LENGTH=$(echo "$SIGNATURE" | grep -o 'length="[^"]*"' | sed 's/length="//;s/"//')

if [ -z "$ED_SIGNATURE" ] || [ -z "$LENGTH" ]; then
    echo "ERROR: Failed to sign. Output was: $SIGNATURE"
    exit 1
fi

echo "  Signature: ${ED_SIGNATURE:0:20}..."
echo "  Length: $LENGTH"

# --- Get release notes from CHANGELOG ---
echo "==> Extracting release notes"
RELEASE_NOTES=$(awk "/^## \[$VERSION\]/{found=1; next} /^## \[/{if(found) exit} found" CHANGELOG.md)
if [ -z "$RELEASE_NOTES" ]; then
    RELEASE_NOTES="Release v$VERSION"
fi

# Escape for XML CDATA
RELEASE_NOTES_XML="<![CDATA[<h2>What's New in v$VERSION</h2><ul>"
while IFS= read -r line; do
    line=$(echo "$line" | sed 's/^- //')
    if [ -n "$line" ] && [[ ! "$line" =~ ^### ]]; then
        RELEASE_NOTES_XML="$RELEASE_NOTES_XML<li>$line</li>"
    fi
done <<< "$RELEASE_NOTES"
RELEASE_NOTES_XML="$RELEASE_NOTES_XML</ul>]]>"

# --- Update appcast.xml ---
echo "==> Updating appcast.xml"
DOWNLOAD_URL="https://github.com/Sota-Mikami/Verba/releases/download/v${VERSION}/${ZIP_NAME}"
PUB_DATE=$(date -R)

cat > "$APPCAST_FILE" << APPCAST_EOF
<?xml version="1.0" encoding="utf-8"?>
<rss version="2.0" xmlns:sparkle="http://www.andymatuschak.org/xml-namespaces/sparkle" xmlns:dc="http://purl.org/dc/elements/1.1/">
    <channel>
        <title>Verba</title>
        <link>https://sota-mikami.github.io/Verba/appcast.xml</link>
        <description>Verba update feed</description>
        <language>en</language>
        <item>
            <title>Version $VERSION</title>
            <description>$RELEASE_NOTES_XML</description>
            <pubDate>$PUB_DATE</pubDate>
            <sparkle:minimumSystemVersion>14.0</sparkle:minimumSystemVersion>
            <enclosure
                url="$DOWNLOAD_URL"
                sparkle:version="1"
                sparkle:shortVersionString="$VERSION"
                sparkle:edSignature="$ED_SIGNATURE"
                length="$LENGTH"
                type="application/octet-stream"
            />
        </item>
    </channel>
</rss>
APPCAST_EOF

echo "==> appcast.xml updated"

# --- Commit & push appcast + version bump ---
echo "==> Committing version bump and appcast"
git add project.yml docs/appcast.xml
git commit -m "Release v$VERSION

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

echo "==> Pushing to GitHub"
git push

# --- Create GitHub Release ---
echo "==> Creating GitHub Release v$VERSION"
gh release create "v$VERSION" \
    "$ZIP_PATH" \
    --title "Verba v$VERSION" \
    --notes "$RELEASE_NOTES" \
    --latest

echo ""
echo "=== Release v$VERSION complete ==="
echo "  GitHub Release: https://github.com/Sota-Mikami/Verba/releases/tag/v$VERSION"
echo "  Appcast:        https://sota-mikami.github.io/Verba/appcast.xml"
echo "  (GitHub Pages will deploy automatically)"
