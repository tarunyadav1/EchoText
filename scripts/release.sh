#!/bin/bash

# EchoText Release Script
# Creates a signed release and uploads it to Cloudflare

set -e

# Configuration
APP_NAME="EchoText"
BUNDLE_ID="com.echotext.app"
BUILD_DIR="build-output/Build/Products/Release"
RELEASES_DIR="releases"
SPARKLE_BIN="build-output/SourcePackages/artifacts/sparkle/Sparkle/bin"
UPDATES_URL="https://echotext-updates.tarunyadav9761.workers.dev"

# Admin secret for updates API (set as environment variable or edit here)
ADMIN_SECRET="${ECHOTEXT_ADMIN_SECRET:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

print_status() {
    echo -e "${GREEN}[*]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[!]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check prerequisites
check_prerequisites() {
    print_status "Checking prerequisites..."

    if [ -z "$ADMIN_SECRET" ]; then
        print_error "ECHOTEXT_ADMIN_SECRET environment variable not set"
        echo "Set it with: export ECHOTEXT_ADMIN_SECRET='your-admin-secret'"
        exit 1
    fi

    if [ ! -f "$SPARKLE_BIN/sign_update" ]; then
        print_error "Sparkle tools not found. Run 'make build' first."
        exit 1
    fi

    if ! command -v jq &> /dev/null; then
        print_error "jq is required. Install with: brew install jq"
        exit 1
    fi
}

# Build the app for release
build_release() {
    print_status "Building release..."

    xcodebuild -project EchoText.xcodeproj \
        -scheme EchoText \
        -configuration Release \
        -derivedDataPath build-output \
        CODE_SIGN_STYLE=Automatic \
        ENABLE_HARDENED_RUNTIME=YES \
        build

    if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
        print_error "Build failed - app not found"
        exit 1
    fi

    print_status "Build complete!"
}

# Get version info from the built app
get_version_info() {
    local plist="$BUILD_DIR/$APP_NAME.app/Contents/Info.plist"
    VERSION=$(/usr/libexec/PlistBuddy -c "Print :CFBundleShortVersionString" "$plist")
    BUILD_NUMBER=$(/usr/libexec/PlistBuddy -c "Print :CFBundleVersion" "$plist")
    MIN_SYSTEM_VERSION=$(/usr/libexec/PlistBuddy -c "Print :LSMinimumSystemVersion" "$plist" 2>/dev/null || echo "14.0")

    print_status "Version: $VERSION (Build $BUILD_NUMBER)"
}

# Create DMG
create_dmg() {
    print_status "Creating DMG..."

    mkdir -p "$RELEASES_DIR"
    DMG_NAME="${APP_NAME}-${VERSION}.dmg"
    DMG_PATH="$RELEASES_DIR/$DMG_NAME"

    # Remove existing DMG
    rm -f "$DMG_PATH"

    # Create temporary directory for DMG contents
    DMG_TEMP=$(mktemp -d)
    cp -R "$BUILD_DIR/$APP_NAME.app" "$DMG_TEMP/"

    # Create a symbolic link to Applications
    ln -s /Applications "$DMG_TEMP/Applications"

    # Create DMG
    hdiutil create -volname "$APP_NAME" \
        -srcfolder "$DMG_TEMP" \
        -ov -format UDZO \
        "$DMG_PATH"

    # Cleanup
    rm -rf "$DMG_TEMP"

    # Get file size
    FILE_SIZE=$(stat -f%z "$DMG_PATH")

    print_status "Created: $DMG_PATH ($FILE_SIZE bytes)"
}

# Sign the DMG with EdDSA
sign_release() {
    print_status "Signing release with EdDSA..."

    # Sign and capture the signature
    SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1 | grep -o 'sparkle:edSignature="[^"]*"' | cut -d'"' -f2)

    if [ -z "$SIGNATURE" ]; then
        # Try alternate format
        SIGNATURE=$("$SPARKLE_BIN/sign_update" "$DMG_PATH" 2>&1 | tail -1)
    fi

    if [ -z "$SIGNATURE" ]; then
        print_error "Failed to sign release"
        exit 1
    fi

    print_status "Signature: ${SIGNATURE:0:20}..."
}

# Upload DMG to R2
upload_to_r2() {
    print_status "Uploading to Cloudflare R2..."

    # Use wrangler to upload
    cd cloudflare-updates-worker
    export CLOUDFLARE_API_TOKEN="${CLOUDFLARE_API_TOKEN:-}"

    if [ -z "$CLOUDFLARE_API_TOKEN" ]; then
        print_warning "CLOUDFLARE_API_TOKEN not set. Trying wrangler login..."
    fi

    npx wrangler r2 object put "echotext-updates/$DMG_NAME" \
        --file="../$DMG_PATH" \
        --content-type="application/octet-stream"

    cd ..

    print_status "Uploaded to R2: $DMG_NAME"
}

# Update appcast via API
update_appcast() {
    print_status "Updating appcast..."

    # Get release notes from CHANGELOG.md if it exists
    RELEASE_NOTES="Bug fixes and improvements."
    if [ -f "CHANGELOG.md" ]; then
        # Try to extract notes for current version
        NOTES=$(awk "/^## \[?${VERSION}\]?/,/^## \[?[0-9]/" CHANGELOG.md | head -n -1 | tail -n +2)
        if [ -n "$NOTES" ]; then
            RELEASE_NOTES="$NOTES"
        fi
    fi

    # Create release via API
    RESPONSE=$(curl -s -X POST "$UPDATES_URL/admin/release" \
        -H "Authorization: Bearer $ADMIN_SECRET" \
        -H "Content-Type: application/json" \
        -d "{
            \"version\": \"$VERSION\",
            \"buildNumber\": \"$BUILD_NUMBER\",
            \"edSignature\": \"$SIGNATURE\",
            \"fileSize\": $FILE_SIZE,
            \"filename\": \"$DMG_NAME\",
            \"releaseNotes\": $(echo "$RELEASE_NOTES" | jq -Rs .),
            \"minimumSystemVersion\": \"$MIN_SYSTEM_VERSION\"
        }")

    if echo "$RESPONSE" | jq -e '.success' > /dev/null 2>&1; then
        print_status "Appcast updated successfully!"
        echo ""
        echo -e "${GREEN}Release Complete!${NC}"
        echo "  Version: $VERSION (Build $BUILD_NUMBER)"
        echo "  DMG: $DMG_PATH"
        echo "  Download URL: $UPDATES_URL/releases/$DMG_NAME"
        echo "  Appcast URL: $UPDATES_URL/appcast.xml"
    else
        print_error "Failed to update appcast:"
        echo "$RESPONSE" | jq .
        exit 1
    fi
}

# Main
main() {
    echo ""
    echo "========================================="
    echo "    EchoText Release Script"
    echo "========================================="
    echo ""

    check_prerequisites

    # Ask for confirmation
    echo "This will:"
    echo "  1. Build the app in Release configuration"
    echo "  2. Create a signed DMG"
    echo "  3. Upload to Cloudflare R2"
    echo "  4. Update the appcast"
    echo ""
    read -p "Continue? (y/n) " -n 1 -r
    echo

    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Aborted."
        exit 0
    fi

    build_release
    get_version_info
    create_dmg
    sign_release
    upload_to_r2
    update_appcast
}

# Run with optional skip flags
if [ "$1" == "--skip-build" ]; then
    check_prerequisites
    get_version_info
    create_dmg
    sign_release
    upload_to_r2
    update_appcast
else
    main
fi
