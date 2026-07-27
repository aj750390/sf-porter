#!/bin/bash

# ==========================================
# SF-PORTER: Sailfish OS Porting Helper
# Device: Poco X3 Pro (vayu)
# Base: Halium 11.0
# ==========================================

DEVICE="vayu"
VENDOR="xiaomi"
ARCH="arm64"
HALIUM_VERSION="11.0"

# Colors for terminal
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

function print_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function print_err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
function print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }

# --- Menu ---
clear
echo "=========================================="
echo " SF-PORTER for $DEVICE"
echo " Halium $HALIUM_VERSION"
echo "=========================================="
echo "1. Init Halium Source & Sync Vayu Tree"
echo "2. Build Halium Images (boot & system)"
echo "3. Setup Droid-Configs"
echo "4. Extract Vendor Blobs"
echo "5. Package Flashable ZIP"
echo "==========================================="
read -p "Select an option [1-5]: " choice

case $choice in
    1)
        echo "Setting up Halium 11.0 build environment..."
        
        # Check if repo tool is installed
        if ! command -v repo &> /dev/null; then
            print_err "Android 'repo' tool not found. Please install it first."
        fi

        # Check if user is in the intended build directory
        read -p "Enter the absolute path to your build directory (e.g., ~/sailfish_vayu): " BUILD_DIR
        mkdir -p "$BUILD_DIR"
        cd "$BUILD_DIR" || print_err "Cannot access $BUILD_DIR"

        # Initialize Halium repo
        print_info "Initializing Halium manifest..."
        repo init -u https://github.com/Halium/halium-manifest -b halium-11.0 --depth=1 || print_err "Repo init failed"

        # Create local manifest for Poco X3 Pro
        print_info "Adding Vayu device tree to local manifests..."
        mkdir -p .repo/local_manifests
        cat << 'EOF' > .repo/local_manifests/vayu.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Note: If these repos 404, you will need to search GitHub for the exact LineageOS 18.1 vayu repos -->
  <project name="LineageOS/android_device_xiaomi_vayu" path="device/xiaomi/vayu" remote="github" revision="lineage-18.1" />
  <project name="LineageOS/android_kernel_xiaomi_vayu" path="kernel/xiaomi/vayu" remote="github" revision="lineage-18.1" />
  <!-- Vendor blobs might need to be pulled from a different source like TheMuppets -->
  <project name="TheMuppets/proprietary_vendor_xiaomi" path="vendor/xiaomi" remote="github" revision="lineage-18.1" />
</manifest>
EOF
        print_ok "Vayu local_manifest created."

        # Sync the source
        print_info "Syncing source code. This will take a long time and download ~50GB+..."
        repo sync -c -j$(nproc --all) --force-sync --no-clone-bundle --no-tags || print_err "Repo sync failed"
        
        print_ok "Halium source and Vayu device tree successfully synced!"
        ;;
    2)
        echo "Building Halium images..."
        # We will build this out next!
        echo "TODO: Implement Halium build commands"
        ;;
    3)
        echo "Setting up droid-configs..."
        # Logic to copy templates from sf-porter/configs/vayu/ into the build tree
        echo "TODO: Implement droid-configs setup"
        ;;
    4)
        echo "Extracting proprietary blobs..."
        echo "TODO: Implement blob extraction"
        ;;
    5)
        echo "Packaging..."
        echo "TODO: Implement zip packaging"
        ;;
    *)
        echo "Invalid option."
        ;;
esac
