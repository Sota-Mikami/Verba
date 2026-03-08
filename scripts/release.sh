#!/bin/bash
set -euo pipefail

# Verba Release Script
# Usage: ./scripts/release.sh [version]
# Example: ./scripts/release.sh 0.3.0
#
# What it does:
# 1. Bumps version in project.yml
# 2. Builds Release binary
# 3. Creates DMG with app-drop-link
# 4. Signs DMG with Sparkle EdDSA
# 5. Updates appcast.xml with signature
# 6. Commits & pushes (triggers GitHub Pages deploy)
# 7. Creates GitHub Release with DMG attached

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SIGN_UPDATE="/tmp/sparkle-build/Build/Products/Release/sign_update"
APPCAST_FILE="$PROJECT_DIR/docs/appcast.xml"
BUILD_DIR="$PROJECT_DIR/build"
DMG_RESOURCES="$PROJECT_DIR/dmg-resources"

cd "$PROJECT_DIR"

# --- Version ---
VERSION="${1:-}"
if [ -z "$VERSION" ]; then
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

for cmd in gh xcodegen create-dmg; do
    if ! command -v "$cmd" &>/dev/null; then
        echo "ERROR: $cmd is required"
        exit 1
    fi
done

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

# --- Create DMG ---
echo "==> Creating DMG"
DMG_NAME="Verba-v${VERSION}.dmg"
DMG_PATH="$BUILD_DIR/$DMG_NAME"

# Remove existing DMG if present
rm -f "$DMG_PATH"

create-dmg \
    --volname "Verba" \
    --background "$DMG_RESOURCES/background.png" \
    --window-pos 200 120 \
    --window-size 660 400 \
    --icon-size 80 \
    --icon "Verba.app" 165 200 \
    --app-drop-link 495 200 \
    --no-internet-enable \
    "$DMG_PATH" \
    "$APP_PATH"

if [ ! -f "$DMG_PATH" ]; then
    echo "ERROR: DMG creation failed"
    exit 1
fi

# --- Sign DMG ---
echo "==> Signing DMG with Sparkle EdDSA"
SIGNATURE=$("$SIGN_UPDATE" "$DMG_PATH" 2>&1)
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
DOWNLOAD_URL="https://github.com/Sota-Mikami/Verba/releases/download/v${VERSION}/${DMG_NAME}"
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
git add project.yml docs/appcast.xml Verba.xcodeproj/project.pbxproj
git commit -m "Release v$VERSION

Co-Authored-By: Claude Opus 4.6 <noreply@anthropic.com>"

echo "==> Pushing to GitHub"
git push

# --- Create GitHub Release ---
echo "==> Creating GitHub Release v$VERSION"
gh release create "v$VERSION" \
    "$DMG_PATH" \
    --title "Verba v$VERSION" \
    --notes "$RELEASE_NOTES" \
    --latest

echo ""
echo "=== Release v$VERSION complete ==="
echo "  GitHub Release: https://github.com/Sota-Mikami/Verba/releases/tag/v$VERSION"
echo "  Appcast:        https://sota-mikami.github.io/Verba/appcast.xml"
echo "  DMG:            $DMG_PATH"
echo "  (GitHub Pages will deploy automatically)"
