#!/bin/bash
# EchoText Developer Setup Script
# Run this once after cloning the repo

set -e

GREEN='\033[0;32m'
YELLOW='\033[0;33m'
RED='\033[0;31m'
NC='\033[0m'

echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  EchoText Developer Setup${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""

# Check if Xcode is installed
if ! command -v xcodebuild &> /dev/null; then
    echo -e "${RED}Error: Xcode is not installed${NC}"
    echo "Please install Xcode from the App Store"
    exit 1
fi

echo -e "${GREEN}[1/4] Resolving Swift Package dependencies...${NC}"
xcodebuild -project EchoText.xcodeproj -scheme EchoText -resolvePackageDependencies

echo ""
echo -e "${GREEN}[2/4] Building the app (first build may take a while)...${NC}"
make build

echo ""
echo -e "${GREEN}[3/4] Build complete!${NC}"
echo ""
echo -e "${YELLOW}[4/4] Setting up permissions...${NC}"
echo ""
echo -e "You need to grant these permissions ONCE:"
echo ""
echo -e "  ${YELLOW}1. Microphone${NC}"
echo -e "     The app will prompt for this on first use."
echo ""
echo -e "  ${YELLOW}2. Accessibility${NC}"
echo -e "     Required for auto-inserting text into other apps."
echo ""
echo -e "     ${GREEN}To add Accessibility permission:${NC}"
echo -e "     a. Open System Settings > Privacy & Security > Accessibility"
echo -e "     b. Click the + button"
echo -e "     c. Navigate to: build-output/Build/Products/Debug/EchoText.app"
echo -e "     d. Add and enable it"
echo ""
echo -e "  ${GREEN}TIP:${NC} With the new ad-hoc signing setup, accessibility"
echo -e "  permissions should persist across rebuilds!"
echo ""

# Ask if user wants to open settings now
read -p "Open Accessibility Settings now? (y/n) " -n 1 -r
echo ""
if [[ $REPLY =~ ^[Yy]$ ]]; then
    open "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
fi

echo ""
echo -e "${GREEN}========================================${NC}"
echo -e "${GREEN}  Setup Complete!${NC}"
echo -e "${GREEN}========================================${NC}"
echo ""
echo "Development commands:"
echo "  make run      - Build and run the app"
echo "  make restart  - Kill and restart the app"
echo "  make build    - Incremental build"
echo "  make help     - Show all commands"
echo ""
