#!/usr/bin/env bash

# ================================================================
# SF-PORTER: Sailfish OS Porting Helper
# Device: Poco X3 Pro (vayu)
# Android base: modified LineageOS 18.1 / Halium 11.0
#
# This script is intentionally conservative:
#   - validate is read-only and never extracts or flashes anything
#   - options 1-3 retain the original WIP build workflow
#   - options 4-5 are not implemented and refuse to operate
# ================================================================

set -u

# Resolve paths from this checkout, not from the caller's directory.
SCRIPT_DIR="$(cd -- "$(dirname -- "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd -- "$SCRIPT_DIR/.." && pwd)"

DEVICE="vayu"
VENDOR="xiaomi"
ARCH="arm64"
HALIUM_VERSION="11.0"
ANDROID_BASE="lineage-18.1"

# Known baseline filenames and hashes from the supplied archive audit.
BASE_ZIP_NAME="lineage-18.1-20220510-UNOFFICIAL-vayu.zip"
SAILFISH_ZIP_NAME="sailfishos-4.5.0.25-20240316-vayu-Verevka.zip"
ADAPTATION_ZIP_NAME="sfos-adaptation-vayu.1.4.zip"
BASE_SHA256="0157305d862c2d6a85362794630ada58204f219c5d616104686b4c6aafd2cfcb"
SAILFISH_SHA256="0089b32e48a40288e8550af2bcb88cd62f5ff3798f3e14c36aedbf082943d846"
ADAPTATION_SHA256="7cd9eb1cd3b2d55a48b3023150ed4361014c623df1376cbe733f68e642cf73e3"

# Colors for terminal output.
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m'

print_ok()   { echo -e "${GREEN}[OK]${NC} $1"; }
print_err()  { echo -e "${RED}[ERROR]${NC} $1" >&2; exit 1; }
print_info() { echo -e "${YELLOW}[INFO]${NC} $1"; }
print_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }

usage() {
    cat <<EOF
Usage:
  $0                         Open the interactive menu
  $0 validate DIRECTORY      Validate the three ZIPs in DIRECTORY
  $0 validate BASE SAILFISH ADAPTATION
  $0 help                    Show this help

The validate command is read-only. It does not extract, flash, mount,
modify, or execute anything from the ZIP files.
EOF
}

# ---------- Dependency and repository helpers ----------

install_dependencies() {
    print_info "Checking and installing required system packages..."
    sudo apt-get update || print_err "apt-get update failed."
    sudo apt-get install -y curl git python3 python-is-python3 \
        ca-certificates git-lfs build-essential libncurses-dev libssl-dev \
        unzip zip || print_err "Failed to install system dependencies."
    git lfs install || print_err "Failed to initialize Git LFS."
    print_ok "System dependencies and Git LFS installed."
}

install_repo_tool() {
    print_info "Android 'repo' tool not found. Installing it to ~/bin..."
    mkdir -p "$HOME/bin" || print_err "Cannot create $HOME/bin."
    curl -fL --retry 3 \
        https://storage.googleapis.com/git-repo-downloads/repo \
        -o "$HOME/bin/repo" || print_err "Failed to download repo tool."
    chmod a+x "$HOME/bin/repo" || print_err "Cannot make repo executable."
    export PATH="$HOME/bin:$PATH"
    print_ok "Repo tool installed for this shell."
    print_info "Open a new terminal later if you want ~/bin loaded automatically."
}

expand_user_path() {
    local value="$1"
    if [[ "$value" == ~/* ]]; then
        printf '%s/%s\n' "$HOME" "${value#~/}"
    else
        printf '%s\n' "$value"
    fi
}

# ---------- Read-only vayu archive validation ----------

validator_failures=0
validator_pass() { printf '[OK] %s\n' "$1"; }
validator_fail() { printf '[FAIL] %s\n' "$1" >&2; validator_failures=$((validator_failures + 1)); }
validator_info() { printf '[INFO] %s\n' "$1"; }

validator_check_file() {
    local label="$1" path="$2"
    if [[ -f "$path" ]]; then
        validator_pass "$label present: $path"
    else
        validator_fail "$label missing: $path"
    fi
}

validator_check_zip() {
    local label="$1" path="$2"
    [[ -f "$path" ]] || return 0
    if unzip -tqq "$path" >/dev/null 2>&1; then
        validator_pass "$label ZIP integrity"
    else
        validator_fail "$label ZIP integrity check failed"
    fi
}

validator_has_entry() {
    local zip="$1" pattern="$2"
    unzip -Z1 "$zip" 2>/dev/null | grep -Eq "$pattern"
}

validator_check_entry() {
    local label="$1" zip="$2" pattern="$3"
    if [[ -f "$zip" ]] && validator_has_entry "$zip" "$pattern"; then
        validator_pass "$label"
    else
        validator_fail "$label"
    fi
}

validator_check_hash() {
    local label="$1" path="$2" expected="$3" expected_name="$4"
    [[ -f "$path" ]] || return 0
    if [[ "$(basename -- "$path")" != "$expected_name" ]]; then
        validator_info "$label hash skipped for custom filename $(basename -- "$path")"
        return 0
    fi
    local actual
    actual="$(sha256sum "$path" | awk '{print $1}')"
    if [[ "$actual" == "$expected" ]]; then
        validator_pass "$label SHA-256 matches baseline"
    else
        validator_fail "$label SHA-256 mismatch: expected $expected, got $actual"
    fi
}

validate_vayu() {
    local base_zip sailfish_zip adaptation_zip

    if [[ $# -eq 1 && -d "$1" ]]; then
        local input_dir
        input_dir="$(cd -- "$1" && pwd)"
        base_zip="$input_dir/$BASE_ZIP_NAME"
        sailfish_zip="$input_dir/$SAILFISH_ZIP_NAME"
        adaptation_zip="$input_dir/$ADAPTATION_ZIP_NAME"
    elif [[ $# -eq 3 ]]; then
        base_zip="$1"
        sailfish_zip="$2"
        adaptation_zip="$3"
    else
        echo "Usage: $0 validate DIRECTORY" >&2
        echo "   or: $0 validate BASE_ZIP SAILFISH_ZIP ADAPTATION_ZIP" >&2
        return 2
    fi

    validator_failures=0
    printf 'sf-porter vayu validator\n'
    printf 'Device: %s | Android base: %s | Halium: %s | Architecture: %s\n\n' \
        "$DEVICE" "$ANDROID_BASE" "$HALIUM_VERSION" "$ARCH"

    validator_check_file "Android base" "$base_zip"
    validator_check_file "Sailfish image" "$sailfish_zip"
    validator_check_file "Device adaptation" "$adaptation_zip"

    validator_check_zip "Android base" "$base_zip"
    validator_check_zip "Sailfish image" "$sailfish_zip"
    validator_check_zip "Device adaptation" "$adaptation_zip"

    validator_check_hash "Android base" "$base_zip" "$BASE_SHA256" "$BASE_ZIP_NAME"
    validator_check_hash "Sailfish image" "$sailfish_zip" "$SAILFISH_SHA256" "$SAILFISH_ZIP_NAME"
    validator_check_hash "Device adaptation" "$adaptation_zip" "$ADAPTATION_SHA256" "$ADAPTATION_ZIP_NAME"

    if [[ -f "$base_zip" ]]; then
        validator_check_entry "Android base has boot.img" "$base_zip" '^boot\.img$'
        validator_check_entry "Android base has dtbo.img" "$base_zip" '^dtbo\.img$'
        validator_check_entry "Android base has vbmeta.img" "$base_zip" '^vbmeta\.img$'
        validator_check_entry "Android base has vendor dynamic payload" "$base_zip" '^vendor\.new\.dat\.br$'
        validator_check_entry "Android base has recovery installer" "$base_zip" '^META-INF/com/google/android/update-binary$'
    fi

    if [[ -f "$sailfish_zip" ]]; then
        validator_check_entry "Sailfish image has sfos-rootfs.tar.bz2" "$sailfish_zip" '^sfos-rootfs\.tar\.bz2$'
        validator_check_entry "Sailfish image has hybris-boot.img" "$sailfish_zip" '^hybris-boot\.img$'
        validator_check_entry "Sailfish image has recovery installer" "$sailfish_zip" '^META-INF/com/google/android/update-binary$'
    fi

    if [[ -f "$adaptation_zip" ]]; then
        validator_check_entry "Adaptation has hybris-dtbo.img" "$adaptation_zip" '^firmware/hybris-dtbo\.img$'
        validator_check_entry "Adaptation has modem firmware" "$adaptation_zip" '^firmware/modem\.img$'
        validator_check_entry "Adaptation has vendor.img" "$adaptation_zip" '^firmware/vendor\.img$'
        validator_check_entry "Adaptation has early-init script" "$adaptation_zip" '^sfos/usr/bin/droid/droid-hal-early-init\.sh$'
        validator_check_entry "Adaptation has setup.sh" "$adaptation_zip" '^setup\.sh$'
    fi

    echo
    if [[ "$validator_failures" -eq 0 ]]; then
        validator_pass "All vayu baseline checks passed"
        validator_info "No files were extracted or modified"
        return 0
    fi

    validator_fail "$validator_failures validation check(s) failed"
    validator_info "No files were extracted or modified"
    return 1
}

# ---------- Interactive build workflow ----------

interactive_menu() {
    clear
    echo "=========================================="
    echo " SF-PORTER for $DEVICE"
    echo " Halium $HALIUM_VERSION"
    echo "=========================================="
    echo "1. Init Halium Source & Sync Vayu Tree"
    echo "2. Build Halium Images (boot & system)"
    echo "3. Setup Droid-Configs & Apply Patches"
    echo "4. Extract Vendor Blobs (not implemented)"
    echo "5. Package Flashable ZIP (not implemented)"
    echo "6. Validate the three vayu ZIPs"
    echo "=========================================="
    read -r -p "Select an option [1-6]: " choice

    case "$choice" in
        1)
            echo "Setting up Halium 11.0 build environment..."
            if ! command -v git >/dev/null 2>&1 || \
               ! command -v python3 >/dev/null 2>&1 || \
               ! command -v curl >/dev/null 2>&1 || \
               ! command -v git-lfs >/dev/null 2>&1; then
                install_dependencies
            fi
            if ! command -v repo >/dev/null 2>&1; then
                install_repo_tool
            fi

            if [[ -z "$(git config --global user.name 2>/dev/null)" || \
                  -z "$(git config --global user.email 2>/dev/null)" ]]; then
                print_warn "Git identity is not configured. Repo may ask for it later."
            fi

            read -r -p "Enter the absolute build directory: " input_dir
            build_dir="$(expand_user_path "$input_dir")"
            mkdir -p "$build_dir" || print_err "Cannot create $build_dir"
            cd "$build_dir" || print_err "Cannot access $build_dir"

            print_info "Initializing Halium manifest..."
            repo init -u https://github.com/Halium/android \
                -b halium-11.0 -g default,-darwin --depth=1 \
                || print_err "Repo init failed."

            print_info "Adding vayu local manifest..."
            mkdir -p .repo/local_manifests
            cat > .repo/local_manifests/vayu.xml <<'EOF'
<?xml version="1.0" encoding="UTF-8"?>
<manifest>
  <project name="LineageOS/android_device_xiaomi_vayu" path="device/xiaomi/vayu" remote="github" revision="lineage-18.1" />
  <project name="LineageOS/android_kernel_xiaomi_sm8150" path="kernel/xiaomi/sm8150" remote="github" revision="lineage-18.1" />
  <project name="the-muppets/proprietary_vendor_xiaomi" path="vendor/xiaomi" remote="gitlab" revision="lineage-18.1" />
</manifest>
EOF
            print_ok "Vayu local manifest created."
            print_warn "This sync downloads tens of gigabytes and may not reproduce Verevka's exact modified Lineage base. Preserve your known-good ZIP."
            read -r -p "Start repo sync now? [y/N]: " confirm_sync
            if [[ "$confirm_sync" =~ ^[Yy]$ ]]; then
                repo sync -c -j2 --force-sync --no-clone-bundle --no-tags \
                    || print_err "Repo sync failed."
                print_ok "Halium source and vayu tree synced."
            else
                print_info "Repo sync cancelled."
            fi
            ;;
        2)
            echo "Building Halium images..."
            read -r -p "Enter the absolute source directory: " input_dir
            build_dir="$(expand_user_path "$input_dir")"
            cd "$build_dir" || print_err "Cannot access $build_dir"
            [[ -f build/envsetup.sh ]] || print_err "Invalid build directory: build/envsetup.sh not found."

            print_info "Setting up build environment..."
            export BUILDTOOL_JAVA_VM_ARGS="-Xmx2G"
            export OUT_DIR="$HOME/sailfish_build_out"
            mkdir -p "$OUT_DIR" || print_err "Cannot create $OUT_DIR"

            # shellcheck disable=SC1091
            source build/envsetup.sh
            lunch "halium_${DEVICE}-userdebug" \
                || print_err "Lunch failed. Check the Halium device tree."

            if [[ ! -f "device/xiaomi/$DEVICE/prebuilt/dtb.img" ]]; then
                print_warn "No prebuilt DTB found; the original WIP build expects one."
            else
                mkdir -p "$OUT_DIR/target/product/$DEVICE"
                cp "device/xiaomi/$DEVICE/prebuilt/dtb.img" \
                    "$OUT_DIR/target/product/$DEVICE/dtb.img" \
                    || print_err "Could not copy prebuilt DTB."
            fi

            print_info "Starting Halium boot and system image build..."
            make -j2 bootimage systemimage || print_err "Halium image build failed."
            print_ok "Images located in $OUT_DIR/target/product/$DEVICE/"
            ;;
        3)
            echo "Setting up droid-configs and applying patches..."
            read -r -p "Enter the absolute source directory: " input_dir
            build_dir="$(expand_user_path "$input_dir")"
            cd "$build_dir" || print_err "Cannot access $build_dir"

            config_source="$PROJECT_ROOT/configs/vayu"
            config_dest="hybris/droid-configs/$DEVICE"
            if [[ ! -d "$config_source/droid-config-vayu" ]]; then
                print_err "Missing config directory: $config_source/droid-config-vayu"
            fi
            mkdir -p "$config_dest" || print_err "Cannot create $config_dest"
            print_info "Copying droid-configs from $config_source"
            cp -a "$config_source/droid-config-vayu/." "$config_dest/" \
                || print_err "Could not copy droid-configs."

            if [[ -s "$config_source/patches/device_tree_hybris.patch" ]]; then
                print_info "Applying device-tree patch..."
                git -C "device/xiaomi/$DEVICE" apply \
                    "$config_source/patches/device_tree_hybris.patch" \
                    || print_warn "Device-tree patch failed or is already applied."
            else
                print_warn "Device-tree patch is empty or missing; skipping."
            fi

            if [[ -s "$config_source/patches/kernel_hybris.patch" ]]; then
                print_info "Applying kernel patch..."
                git -C "kernel/xiaomi/sm8150" apply \
                    "$config_source/patches/kernel_hybris.patch" \
                    || print_warn "Kernel patch failed or is already applied."
            else
                print_warn "Kernel patch is empty or missing; skipping."
            fi

            print_warn "The current WIP config and patch files are placeholders until we import the real working vayu adaptation data."
            print_ok "Droid-config copy and patch stage completed."
            ;;
        4)
            print_err "Vendor extraction is not implemented yet. Do not use this option."
            ;;
        5)
            print_err "Flashable ZIP packaging is not implemented yet. Do not use this option."
            ;;
        6)
            read -r -p "Enter the directory containing the three ZIPs: " input_dir
            validate_vayu "$(expand_user_path "$input_dir")"
            ;;
        *)
            print_err "Invalid option."
            ;;
    esac
}

# ---------- Entry point ----------

case "${1:-menu}" in
    validate)
        shift
        validate_vayu "$@"
        ;;
    help|--help|-h)
        usage
        ;;
    menu)
        interactive_menu
        ;;
    *)
        usage >&2
        exit 2
        ;;
esac
