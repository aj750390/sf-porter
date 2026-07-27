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

# Print functions
function print_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function print_err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }
function print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
function print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

# --- Menu ---
clear
echo "=========================================="
echo " SF-PORTER for $DEVICE"
echo " Halium $HALIUM_VERSION"
echo "=========================================="
echo "1. Init Halium Source & Sync Vayu Tree"
echo "2. Build Halium Images (boot & system)"
echo "3. Setup Droid-Configs & Apply Patches"
echo "4. Extract Vendor Blobs (Placeholder)"
echo "5. Package Flashable ZIP (Placeholder)"
echo "=========================================="
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
        # Ensure we are in the build dir
        if [ ! -d "out/target/product/$DEVICE" ]; then
            print_err "Build directory not found. Did you run Option 1 first?"
        fi

        print_info "Setting up build environment..."
        source build/envsetup.sh
        lunch halium_$DEVICE-userdebug || print_err "Lunch failed. Check your device tree."

        print_info "Starting Halium boot and system image build. This will take a long time..."
        mka halium-boot systemimage || print_err "Build failed!"

        print_ok "Build complete!"
        print_ok "Images located in: out/target/product/$DEVICE/"
        ;;
    3)
        echo "Setting up droid-configs and applying patches..."
        
        # IMPORTANT: Change this path if your sf-porter folder is located somewhere else!
        CONFIG_SOURCE="$HOME/sf-porter/configs/vayu" 
        
        CONFIG_DEST="hybris/droid-configs/$DEVICE"

        # Create destination directory
        mkdir -p $CONFIG_DEST

        # Copy droid-configs template
        print_info "Copying droid-configs to $CONFIG_DEST..."
        cp -r $CONFIG_SOURCE/droid-config-vayu/* $CONFIG_DEST/

        # Apply patches (if any exist and have content)
        if [ -s "$CONFIG_SOURCE/patches/device_tree_hybris.patch" ]; then
            print_info "Applying device tree patches..."
            git -C device/xiaomi/$DEVICE apply $CONFIG_SOURCE/patches/device_tree_hybris.patch || print_warn "Device tree patch failed or already applied."
        else
            print_warn "No device tree patch found (or file is empty). Skipping."
        fi

        if [ -s "$CONFIG_SOURCE/patches/kernel_hybris.patch" ]; then
            print_info "Applying kernel patches..."
            git -C kernel/xiaomi/$DEVICE apply $CONFIG_SOURCE/patches/kernel_hybris.patch || print_warn "Kernel patch failed or already applied."
        else
            print_warn "No kernel patch found (or file is empty). Skipping."
        fi

        # Initialize git in the droid-configs folder (prevents the 'fatal: not a git repository' error!)
        cd $CONFIG_DEST
        if [ ! -d ".git" ]; then
            git init
            git add .
            git commit -m "Initial droid-configs for vayu"
            print_ok "Initialized Git in $CONFIG_DEST"
        else
            print_ok "Git already initialized in $CONFIG_DEST"
        fi
        cd ../../../
        
        print_ok "Droid-configs and patches applied successfully!"
        ;;
    4)
        echo "Extracting Vendor Blobs..."
        # We will build this out in the next step
        echo "TODO: Implement logic to mount system.img and pull .so files for libhybris"
        ;;
    5)
        echo "Packaging..."
        # We will build this out in the next step
        echo "TODO: Implement logic to generate META-INF and zip the flashable package"
        ;;
    *)
        echo "Invalid option. Exiting."
        ;;
esac
