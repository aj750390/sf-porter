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
NC='\033[0m' # No Color

function print_ok() { echo -e "${GREEN}[OK]${NC} $1"; }
function print_err() { echo -e "${RED}[ERROR]${NC} $1"; exit 1; }

# --- Menu ---
echo "SF-PORTER for $DEVICE"
echo "1. Setup Droid-Configs Template"
echo "2. Build Halium Images (boot & system)"
echo "3. Extract Vendor Blobs"
echo "4. Build Sailfish Rootfs (Placeholder)"
echo "5. Package Flashable ZIP"
read -p "Select an option [1-5]: " choice

case $choice in
    1)
        echo "Setting up droid-configs..."
        # 1. Check if repo exists
        if [ ! -d ".repo" ]; then
            print_err "This is not a Halium build tree. Run from the root of the source."
        fi

        # 2. Create droid-config directory structure
        CONFIG_DIR="hybris/droid-configs"
        mkdir -p $CONFIG_DIR
        
        # 3. Initialize git in the configs folder (prevents the error you had earlier!)
        cd $CONFIG_DIR
        if [ ! -d ".git" ]; then
            git init
            print_ok "Initialized Git in $CONFIG_DIR"
        fi
        
        # 4. Create basic droid-config files
        mkdir -p $DEVICE
        echo "ro.hardware=qcom" > $DEVICE/system.prop
        echo "Created $DEVICE/system.prop"
        
        cd ../../
        print_ok "Droid-configs template created. You still need to manually edit audio/sensor configs!"
        ;;
    2)
        echo "Building Halium images..."
        source build/envsetup.sh
        lunch halium_$DEVICE-userdebug || print_err "Lunch failed"
        mka halium-boot systemimage || print_err "Build failed"
        print_ok "Halium boot.img and system.img built successfully in out/target/product/$DEVICE/"
        ;;
    3)
        echo "Extracting proprietary blobs from built system.img..."
        IMG_PATH="out/target/product/$DEVICE/system.img"
        if [ ! -f "$IMG_PATH" ]; then
            print_err "system.img not found. Run option 2 first."
        fi
        
        mkdir -p extracted_blobs
        sudo mount -t ext4 -o loop $IMG_PATH extracted_blobs
        # Here you would add logic to copy specific .so files needed for libhybris
        sudo umount extracted_blobs
        print_ok "Extraction complete."
        ;;
    4)
        echo "Building Sailfish Rootfs..."
        # This would normally call the Sailfish SDK 'mic' tool
        # We will build this part out later
        echo "TODO: Implement mic image creator integration"
        ;;
    5)
        echo "Packaging..."
        # Combine boot.img, system.img, and rootfs into an edify script zip
        # TODO: Create META-INF/com/google/android/update-binary
        echo "TODO: Implement zip packaging"
        ;;
    *)
        echo "Invalid option."
        ;;
esac
