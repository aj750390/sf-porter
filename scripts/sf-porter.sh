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

# Function to automatically install build dependencies
function install_dependencies() {
    print_info "Checking and installing required system packages..."
    
    # Update apt and install curl, git, python3, and git-lfs
    sudo apt-get update
    sudo apt-get install -y curl git python3 python-is-python3 ca-certificates git-lfs build-essential libncurses-dev || print_err "Failed to install system dependencies."
    
    # Initialize Git LFS
    git lfs install || print_err "Failed to initialize Git LFS."
    
    print_ok "System dependencies and Git LFS installed."
}

# Function to automatically install the Android repo tool
function install_repo_tool() {
    print_info "Android 'repo' tool not found. Installing it automatically..."
    
    mkdir -p ~/bin
    
    print_info "Downloading repo tool..."
    curl -s https://storage.googleapis.com/git-repo-downloads/repo > ~/bin/repo || print_err "Failed to download repo tool."
    chmod a+x ~/bin/repo
    
    # Add to .bashrc if not already there
    if ! grep -q 'export PATH=~/bin:$PATH' ~/.bashrc; then
        echo 'export PATH=~/bin:$PATH' >> ~/.bashrc
    fi
    
    # Make it available in the current session
    export PATH=~/bin:$PATH
    print_ok "Repo tool installed successfully!"
}

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
        
        # Ensure git, python3, curl, and git-lfs are installed
        if ! command -v git &> /dev/null || ! command -v python3 &> /dev/null || ! command -v curl &> /dev/null || ! command -v git-lfs &> /dev/null; then
            install_dependencies
        fi

        # Check if repo tool is installed, if not, install it!
        if ! command -v repo &> /dev/null; then
            install_repo_tool
        fi

        # Check if Git user name and email are configured (required by repo tool!)
        if [ -z "$(git config --global user.name)" ] || [ -z "$(git config --global user.email)" ]; then
            print_info "Git identity not found. Configuring default identity for repo tool..."
            git config --global user.name "SF-Porter User"
            git config --global user.email "sfporter@example.com"
            print_ok "Git identity configured."
        fi

        # Check if user is in the intended build directory
        read -p "Enter the absolute path to your build directory (e.g., ~/sailfish_vayu or /media/user/sailfish/sailfish_vayu): " INPUT_DIR
        # Expand the ~ symbol to the real home directory path
        BUILD_DIR=$(eval echo "$INPUT_DIR")
        mkdir -p "$BUILD_DIR"
        cd "$BUILD_DIR" || print_err "Cannot access $BUILD_DIR"

        # Initialize Halium repo (-g default,-darwin skips macOS files to save space/time)
        print_info "Initializing Halium manifest..."
        repo init -u https://github.com/Halium/android -b halium-11.0 -g default,-darwin --depth=1 || print_err "Repo init failed"

        # Create local manifest for Poco X3 Pro
        print_info "Adding Vayu device tree to local manifests..."
        mkdir -p .repo/local_manifests
        cat << 'EOF' > .repo/local_manifests/vayu.xml
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <!-- Define the GitLab remote -->
  <remote name="gitlab" fetch="https://gitlab.com" />
  
  <project name="LineageOS/android_device_xiaomi_vayu" path="device/xiaomi/vayu" remote="github" revision="lineage-18.1" />
  <project name="LineageOS/android_kernel_xiaomi_sm8150" path="kernel/xiaomi/sm8150" remote="github" revision="lineage-18.1" />
  
  <!-- Point the vendor repository to the GitLab mirror -->
  <project name="the-muppets/proprietary_vendor_xiaomi" path="vendor/xiaomi" remote="gitlab" revision="lineage-18.1" />
</manifest>
EOF
        print_ok "Vayu local_manifest created."

        # Sync the source
        print_info "Syncing source code. This will take a long time and download ~50GB+..."
        print_warn "Using -j2 and skipping darwin files to prevent 429 errors and save space."
        
        # Use -j2 for safe downloading to avoid Google rate limits (429 errors)
        repo sync -c -j2 --force-sync --no-clone-bundle --no-tags || \
        print_err "Repo sync failed. Try again later or use a VPN."
        
        print_ok "Halium source and Vayu device tree successfully synced!"
        ;;
    2)
        echo "Building Halium images..."
        # Ask for the build directory
        read -p "Enter the absolute path to your source directory (e.g., /media/user/sailfish/sailfish_vayu): " INPUT_DIR
        BUILD_DIR=$(eval echo "$INPUT_DIR")
        cd "$BUILD_DIR" || print_err "Cannot access $BUILD_DIR"

        # Ensure we are in the build dir
        if [ ! -f "build/envsetup.sh" ]; then
            print_err "Build directory invalid or source not synced. Did you run Option 1 first?"
        fi

        print_info "Setting up build environment..."
        
        # Limit Java heap size to 2GB to prevent Out of Memory (Killed) errors
        export BUILDTOOL_JAVA_VM_ARGS="-Xmx2G"
        
        # Put the build cache (out/) on the fast internal SSD!
        mkdir -p $HOME/sailfish_build_out
        export OUT_DIR=$HOME/sailfish_build_out
        
        # Force kernel variables into the environment (fixes missing 'make' and 'ARCH=')
        export KERNEL_MAKE_CMD=make
        export KERNEL_ARCH=arm64
        export TARGET_KERNEL_ARCH=arm64
        export TARGET_KERNEL_SOURCE=kernel/xiaomi/sm8150
        export TARGET_KERNEL_CONFIG=vendor/vayu_defconfig
        
        # Force the shell to use ARM64 architecture for the kernel
        export ARCH=arm64
        export CROSS_COMPILE=$BUILD_DIR/prebuilts/gcc/linux-x86/aarch64/aarch64-linux-android-4.9/bin/aarch64-linux-android-
        export CROSS_COMPILE_ARM32=$BUILD_DIR/prebuilts/gcc/linux-x86/arm/arm-linux-androideabi-4.9/bin/arm-linux-androideabi-
        
        export HOSTCC=gcc
        
        # Force Clang to ignore strict warnings in the older kernel
        export KCFLAGS="-Wno-array-bounds -Wno-error"
        export CFLAGS="-Wno-array-bounds -Wno-error"
        export KCPPFLAGS="-Wno-error"
        
        # FIX: Force the legacy kernel VDSO to compile with GNU assembler instead of Clang's IAS
        print_info "Patching VDSO Makefile for Clang 11 compatibility..."
        if ! grep -q "\-no-integrated-as" kernel/xiaomi/sm8150/arch/arm64/kernel/vdso/Makefile; then
            echo "ccflags-y += -no-integrated-as" >> kernel/xiaomi/sm8150/arch/arm64/kernel/vdso/Makefile
        fi
        
        source build/envsetup.sh
        lunch halium_$DEVICE-userdebug || print_err "Lunch failed. Check your device tree (make sure halium_vayu.mk exists)."

        print_info "Starting Halium boot and system image build. This will take a long time..."
        # Use -j2 to limit RAM usage. Change to -j1 if it still gets Killed.
        make -j2 bootimage systemimage || print_err "Build failed!"

        print_ok "Build complete!"
        print_ok "Images located in: $OUT_DIR/target/product/$DEVICE/"
        ;;
    3)
        echo "Setting up droid-configs and applying patches..."
        
        # Ask for the build directory to ensure we patch the right files
        read -p "Enter the absolute path to your source directory (e.g., /media/user/sailfish/sailfish_vayu): " INPUT_DIR
        BUILD_DIR=$(eval echo "$INPUT_DIR")
        cd "$BUILD_DIR" || print_err "Cannot access $BUILD_DIR"

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
            git -C kernel/xiaomi/sm8150 apply $CONFIG_SOURCE/patches/kernel_hybris.patch || print_warn "Kernel patch failed or already applied."
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
        cd "$BUILD_DIR"
        
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
