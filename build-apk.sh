#!/bin/bash
#
# Unified AI Gateway - APK Build Script
# Builds the complete Flutter APK with embedded Node.js gateway
#

set -e

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

echo -e "${BLUE}"
echo "╔═══════════════════════════════════════════╗"
echo "║   Unified AI Gateway - APK Builder       ║"
echo "║   Free Cloud LLM Access on Android        ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Check if running in correct directory
if [ ! -d "flutter_app" ]; then
    echo -e "${RED}Error: Please run this script from the unified-ai-gateway root directory${NC}"
    exit 1
fi

# Check for Flutter
if ! command -v flutter &> /dev/null; then
    echo -e "${RED}Error: Flutter is not installed${NC}"
    echo "Install Flutter from: https://docs.flutter.dev/get-started/install"
    exit 1
fi

# Check for Android SDK
if [ -z "$ANDROID_HOME" ] && [ -z "$ANDROID_SDK_ROOT" ]; then
    echo -e "${YELLOW}Warning: ANDROID_HOME not set, using default paths${NC}"
    export ANDROID_HOME="$HOME/Android/Sdk"
    export ANDROID_SDK_ROOT="$HOME/Android/Sdk"
fi

# Navigate to Flutter app
cd flutter_app

echo -e "\n${BLUE}[1/4]${NC} Cleaning previous builds..."
flutter clean

echo -e "\n${BLUE}[2/4]${NC} Getting Flutter dependencies..."
flutter pub get

echo -e "\n${BLUE}[3/4]${NC} Analyzing code..."
flutter analyze || {
    echo -e "${YELLOW}Analysis warnings found, continuing anyway...${NC}"
}

echo -e "\n${BLUE}[4/4]${NC} Building APK..."
echo ""
echo "Select build type:"
echo "  1) Debug APK (fast, for testing)"
echo "  2) Release APK (optimized, for distribution)"
echo "  3) Release APK per ABI (arm64, armeabi, x86_64)"
echo "  4) App Bundle (for Play Store)"
read -p "Enter choice (1-4): " build_choice

case $build_choice in
    1)
        echo -e "\n${GREEN}Building Debug APK...${NC}"
        flutter build apk --debug
        echo -e "\n${GREEN}✓ Debug APK built successfully!${NC}"
        echo "Location: build/app/outputs/flutter-apk/app-debug.apk"
        ;;
    2)
        echo -e "\n${GREEN}Building Release APK...${NC}"
        flutter build apk --release
        echo -e "\n${GREEN}✓ Release APK built successfully!${NC}"
        echo "Location: build/app/outputs/flutter-apk/app-release.apk"
        ;;
    3)
        echo -e "\n${GREEN}Building Release APKs per ABI...${NC}"
        flutter build apk --release --split-per-abi
        echo -e "\n${GREEN}✓ Release APKs built successfully!${NC}"
        echo "Locations:"
        echo "  - build/app/outputs/flutter-apk/app-arm64-v8a-release.apk"
        echo "  - build/app/outputs/flutter-apk/app-armeabi-v7a-release.apk"
        echo "  - build/app/outputs/flutter-apk/app-x86_64-release.apk"
        ;;
    4)
        echo -e "\n${GREEN}Building App Bundle...${NC}"
        flutter build appbundle --release
        echo -e "\n${GREEN}✓ App Bundle built successfully!${NC}"
        echo "Location: build/app/outputs/bundle/release/app-release.aab"
        ;;
    *)
        echo -e "${RED}Invalid choice${NC}"
        exit 1
        ;;
esac

echo -e "\n${GREEN}═══════════════════════════════════════════${NC}"
echo -e "${GREEN}Build Complete!${NC}"
echo -e "${GREEN}═══════════════════════════════════════════${NC}"

echo -e "\n${YELLOW}Next steps:${NC}"
echo "  1. Install APK on your Android device"
echo "  2. Open the app and complete setup"
echo "  3. Pull models from the Models screen"
echo "  4. Start the Gateway and begin using AI!"
echo ""
echo -e "${BLUE}API Endpoints:${NC}"
echo "  HTTP: http://localhost:18789"
echo "  WebSocket: ws://localhost:18790"
echo ""
echo -e "${YELLOW}Note:${NC} Disable battery optimization for the app in Android settings"
echo ""
