#!/bin/bash
#
# Unified AI Gateway - Keystore Setup Script
# Generates a signing key for release APKs
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
echo "║   Unified AI Gateway - Keystore Setup    ║"
echo "╚═══════════════════════════════════════════╝"
echo -e "${NC}"

# Configuration
KEYSTORE_DIR="${HOME}/.unified-ai-gateway/keystore"
KEYSTORE_FILE="${KEYSTORE_DIR}/unified-gateway-release.keystore"
KEY_ALIAS="unified-gateway"
KEYSTORE_PASSWORD=""
KEY_PASSWORD=""
VALIDITY=10000

# Prompt for credentials
echo -e "${YELLOW}Enter keystore credentials:${NC}"
echo ""

read -p "Keystore password (leave empty for random): " KEYSTORE_PASSWORD
if [ -z "$KEYSTORE_PASSWORD" ]; then
    KEYSTORE_PASSWORD=$(openssl rand -base64 32 | tr -dc 'a-zA-Z0-9' | head -c 20)
    echo -e "${YELLOW}Generated random password: ${KEYSTORE_PASSWORD}${NC}"
fi

read -p "Key password (leave empty for same as keystore): " KEY_PASSWORD
if [ -z "$KEY_PASSWORD" ]; then
    KEY_PASSWORD="$KEYSTORE_PASSWORD"
    echo -e "${YELLOW}Using same password as keystore${NC}"
fi

read -p "Your name (for certificate DN): " YOUR_NAME
read -p "Your organization: " YOUR_ORG
read -p "Your city: " YOUR_CITY
read -p "Your state/province: " YOUR_STATE
read -p "Your country code (2 letters): " YOUR_COUNTRY

# Create keystore directory
mkdir -p "$KEYSTORE_DIR"

# Generate keystore
echo ""
echo -e "${BLUE}Generating keystore...${NC}"

keytool -genkeypair -v \
    -keystore "$KEYSTORE_FILE" \
    -alias "$KEY_ALIAS" \
    -storepass "$KEYSTORE_PASSWORD" \
    -keypass "$KEY_PASSWORD" \
    -keyalg RSA \
    -keysize 2048 \
    -validity $VALIDITY \
    -dname "CN=$YOUR_NAME, OU=$YOUR_ORG, O=$YOUR_ORG, L=$YOUR_CITY, ST=$YOUR_STATE, C=$YOUR_COUNTRY"

echo -e "\n${GREEN}✓ Keystore generated successfully!${NC}"
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}IMPORTANT - Save this information!${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""
echo "Keystore location: $KEYSTORE_FILE"
echo "Key alias: $KEY_ALIAS"
echo "Keystore password: $KEYSTORE_PASSWORD"
echo "Key password: $KEY_PASSWORD"
echo ""
echo -e "${RED}⚠️  WARNING: Store these credentials securely!${NC}"
echo -e "${RED}   If you lose them, you cannot update your app!${NC}"
echo ""

# Create key.properties for Flutter
echo -e "${BLUE}Creating key.properties for Flutter...${NC}"

KEY_PROPERTIES_FILE="flutter_app/android/key.properties"
cat > "$KEY_PROPERTIES_FILE" << EOF
# Unified AI Gateway - Android Signing Key
# Generated: $(date)
#
# IMPORTANT: Keep this file secure! Do not commit to version control.

storePassword=$KEYSTORE_PASSWORD
keyPassword=$KEY_PASSWORD
keyAlias=$KEY_ALIAS
storeFile=$KEYSTORE_FILE
EOF

echo -e "${GREEN}✓ key.properties created at: $KEY_PROPERTIES_FILE${NC}"
echo ""

# Add to .gitignore
echo -e "${BLUE}Updating .gitignore...${NC}"

GITIGNORE_FILE=".gitignore"
if ! grep -q "key.properties" "$GITIGNORE_FILE" 2>/dev/null; then
    cat >> "$GITIGNORE_FILE" << EOF

# Android signing keys
flutter_app/android/key.properties
*.keystore
*.jks
EOF
    echo -e "${GREEN}✓ Added signing files to .gitignore${NC}"
else
    echo -e "${YELLOW}⚠️  key.properties already in .gitignore${NC}"
fi

# Create backup instructions
echo ""
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo -e "${YELLOW}Next Steps:${NC}"
echo -e "${YELLOW}═══════════════════════════════════════════${NC}"
echo ""
echo "1. Backup your keystore file:"
echo "   cp $KEYSTORE_FILE /secure/backup/location/"
echo ""
echo "2. Backup your credentials (save to password manager):"
echo "   - Keystore: $KEYSTORE_FILE"
echo "   - Alias: $KEY_ALIAS"
echo "   - Passwords: (see above)"
echo ""
echo "3. Build signed APK:"
echo "   cd flutter_app"
echo "   flutter build apk --release"
echo ""
echo "4. For GitHub Actions, encode the keystore:"
echo "   base64 $KEYSTORE_FILE > keystore.base64"
echo "   # Add keystore.base64 content to GitHub Secrets as KEYSTORE_BASE64"
echo ""
echo -e "${GREEN}Setup complete!${NC}"
