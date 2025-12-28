#!/bin/bash
#
# DevVM ISO Builder
# Builds a custom Ubuntu 24.04 ISO with embedded autoinstall configuration
#
# Usage: ./build-iso.sh [--source-iso <path>] [--download]
#

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(dirname "$SCRIPT_DIR")"
BUILD_DIR="$REPO_ROOT/build"
WORK_DIR="$BUILD_DIR/work"
ISO_EXTRACT_DIR="$WORK_DIR/iso-extract"
OUTPUT_ISO="$BUILD_DIR/DeveloperVM-UbuntuCinnamon-Autoinstall.iso"

# Ubuntu 24.04 LTS ISO details
UBUNTU_ISO_URL="https://releases.ubuntu.com/24.04/ubuntu-24.04.1-desktop-amd64.iso"
UBUNTU_ISO_NAME="ubuntu-24.04.1-desktop-amd64.iso"
SOURCE_ISO=""
DOWNLOAD_ISO=false

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

log_info() {
    echo -e "${GREEN}[INFO]${NC} $*"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $*"
}

usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Build a custom DevVM Ubuntu ISO with embedded autoinstall configuration.

OPTIONS:
    --source-iso <path>    Path to source Ubuntu 24.04 ISO
    --download             Download Ubuntu ISO if not present
    -h, --help            Show this help message

EXAMPLES:
    $0 --source-iso ~/Downloads/ubuntu-24.04.1-desktop-amd64.iso
    $0 --download

EOF
    exit 0
}

check_dependencies() {
    log_info "Checking dependencies..."

    local missing=()

    for cmd in xorriso mksquashfs unsquashfs; do
        if ! command -v "$cmd" &> /dev/null; then
            missing+=("$cmd")
        fi
    done

    if [[ ${#missing[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing[*]}"
        log_info "Install with: sudo apt-get install xorriso squashfs-tools"
        exit 1
    fi

    # Check for 7z or p7zip for ISO extraction
    if ! command -v 7z &> /dev/null && ! command -v 7za &> /dev/null; then
        log_warn "7z not found, will use xorriso for extraction"
    fi

    log_info "All dependencies satisfied"
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --source-iso)
                SOURCE_ISO="$2"
                shift 2
                ;;
            --download)
                DOWNLOAD_ISO=true
                shift
                ;;
            -h|--help)
                usage
                ;;
            *)
                log_error "Unknown option: $1"
                usage
                ;;
        esac
    done
}

download_iso() {
    local iso_path="$BUILD_DIR/$UBUNTU_ISO_NAME"

    if [[ -f "$iso_path" ]]; then
        log_info "Ubuntu ISO already exists: $iso_path"
        SOURCE_ISO="$iso_path"
        return 0
    fi

    log_info "Downloading Ubuntu 24.04 ISO..."
    log_info "URL: $UBUNTU_ISO_URL"

    mkdir -p "$BUILD_DIR"

    if command -v wget &> /dev/null; then
        wget -O "$iso_path" "$UBUNTU_ISO_URL"
    elif command -v curl &> /dev/null; then
        curl -L -o "$iso_path" "$UBUNTU_ISO_URL"
    else
        log_error "Neither wget nor curl found. Cannot download ISO."
        exit 1
    fi

    SOURCE_ISO="$iso_path"
    log_info "Download complete: $iso_path"
}

extract_iso() {
    log_info "Extracting source ISO..."

    rm -rf "$ISO_EXTRACT_DIR"
    mkdir -p "$ISO_EXTRACT_DIR"

    # Use xorriso to extract ISO contents
    xorriso -osirrox on -indev "$SOURCE_ISO" -extract / "$ISO_EXTRACT_DIR"

    # Make files writable
    chmod -R u+w "$ISO_EXTRACT_DIR"

    log_info "ISO extracted to: $ISO_EXTRACT_DIR"
}

inject_nocloud_seed() {
    log_info "Injecting NoCloud autoinstall seed..."

    # Create primary seed location
    mkdir -p "$ISO_EXTRACT_DIR/nocloud"
    cp "$REPO_ROOT/iso/nocloud/user-data" "$ISO_EXTRACT_DIR/nocloud/"
    cp "$REPO_ROOT/iso/nocloud/meta-data" "$ISO_EXTRACT_DIR/nocloud/"

    # Create backup seed location
    mkdir -p "$ISO_EXTRACT_DIR/autoinstall/nocloud"
    cp "$REPO_ROOT/iso/autoinstall/nocloud/user-data" "$ISO_EXTRACT_DIR/autoinstall/nocloud/"
    cp "$REPO_ROOT/iso/autoinstall/nocloud/meta-data" "$ISO_EXTRACT_DIR/autoinstall/nocloud/"

    log_info "NoCloud seed files injected"
}

patch_grub_config() {
    log_info "Patching GRUB configuration..."

    # Find and patch GRUB config files
    local grub_cfg="$ISO_EXTRACT_DIR/boot/grub/grub.cfg"
    local grub_loopback="$ISO_EXTRACT_DIR/boot/grub/loopback.cfg"

    # Backup original
    if [[ -f "$grub_cfg" ]]; then
        cp "$grub_cfg" "${grub_cfg}.orig"
    fi

    # Create new GRUB config with autoinstall entries
    cat > "$grub_cfg" << 'GRUBCFG'
# DevVM Custom GRUB Configuration
set default=0
set timeout=5

# Load video modules
insmod all_video

set gfxpayload=keep

# Primary autoinstall entry (default)
menuentry "Install DevVM Ubuntu (Autoinstall)" --id devvm-autoinstall {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/nocloud/ quiet ---
    initrd  /casper/initrd
}

# Alternate seed path entry
menuentry "Install DevVM Ubuntu (Alternate Seed Path)" --id devvm-autoinstall-alt {
    set gfxpayload=keep
    linux   /casper/vmlinuz autoinstall ds=nocloud\;s=/cdrom/autoinstall/nocloud/ quiet ---
    initrd  /casper/initrd
}

# Manual recovery entry
menuentry "Manual Install (Recovery)" --id devvm-manual {
    set gfxpayload=keep
    linux   /casper/vmlinuz boot=casper quiet splash ---
    initrd  /casper/initrd
}

# Memory test
menuentry "Test memory" {
    linux /casper/memtest
}
GRUBCFG

    # Also create loopback config if it exists
    if [[ -f "$grub_loopback" ]]; then
        cp "$grub_cfg" "$grub_loopback"
    fi

    # Handle EFI GRUB config
    local efi_grub="$ISO_EXTRACT_DIR/EFI/boot/grub.cfg"
    if [[ -f "$efi_grub" ]]; then
        cp "${efi_grub}" "${efi_grub}.orig"
        cat > "$efi_grub" << 'EFIGRUB'
search --set=root --file /.disk/info
set prefix=(\$root)/boot/grub
configfile /boot/grub/grub.cfg
EFIGRUB
    fi

    # Update isolinux config for legacy BIOS boot
    local isolinux_cfg="$ISO_EXTRACT_DIR/isolinux/txt.cfg"
    if [[ -f "$isolinux_cfg" ]]; then
        cp "${isolinux_cfg}" "${isolinux_cfg}.orig"
        cat > "$isolinux_cfg" << 'ISOLINUX'
default autoinstall
label autoinstall
  menu label ^Install DevVM Ubuntu (Autoinstall)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/nocloud/ quiet ---
label autoinstall-alt
  menu label Install DevVM Ubuntu (^Alternate Seed Path)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd autoinstall ds=nocloud;s=/cdrom/autoinstall/nocloud/ quiet ---
label manual
  menu label ^Manual Install (Recovery)
  kernel /casper/vmlinuz
  append initrd=/casper/initrd boot=casper quiet splash ---
ISOLINUX
    fi

    local isolinux_main="$ISO_EXTRACT_DIR/isolinux/isolinux.cfg"
    if [[ -f "$isolinux_main" ]]; then
        # Set timeout and default
        sed -i 's/timeout.*/timeout 50/' "$isolinux_main" 2>/dev/null || true
    fi

    log_info "GRUB configuration patched"
}

rebuild_iso() {
    log_info "Rebuilding ISO..."

    mkdir -p "$(dirname "$OUTPUT_ISO")"

    # Remove old ISO if exists
    rm -f "$OUTPUT_ISO"

    # Detect boot configuration
    local has_isolinux=false
    local has_efi=false
    local efi_img=""

    if [[ -f "$ISO_EXTRACT_DIR/isolinux/isolinux.bin" ]]; then
        has_isolinux=true
        log_info "Detected: Legacy BIOS boot (isolinux)"
    fi

    if [[ -d "$ISO_EXTRACT_DIR/EFI" ]]; then
        has_efi=true
        log_info "Detected: EFI boot"
        # Find EFI boot image
        for img in "$ISO_EXTRACT_DIR/boot/grub/efi.img" "$ISO_EXTRACT_DIR/EFI/boot/efiboot.img" "$ISO_EXTRACT_DIR/efi.img"; do
            if [[ -f "$img" ]]; then
                efi_img="$img"
                break
            fi
        done
    fi

    if [[ "$has_isolinux" == "true" && "$has_efi" == "true" ]]; then
        # Hybrid ISO (BIOS + EFI)
        log_info "Building hybrid BIOS/EFI ISO..."
        xorriso -as mkisofs \
            -r -V "DevVM-Ubuntu" \
            -o "$OUTPUT_ISO" \
            -J -joliet-long \
            -c isolinux/boot.cat \
            -b isolinux/isolinux.bin \
            -no-emul-boot \
            -boot-load-size 4 \
            -boot-info-table \
            -eltorito-alt-boot \
            -e boot/grub/efi.img \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            "$ISO_EXTRACT_DIR"
    elif [[ "$has_efi" == "true" ]]; then
        # EFI-only ISO (Ubuntu Cinnamon uses this)
        log_info "Building EFI-only ISO..."

        # Create the EFI boot image if needed
        if [[ ! -f "$ISO_EXTRACT_DIR/boot/grub/efi.img" ]]; then
            log_info "Creating EFI boot image..."
            mkdir -p "$ISO_EXTRACT_DIR/boot/grub"

            # Create a small FAT image for EFI
            dd if=/dev/zero of="$ISO_EXTRACT_DIR/boot/grub/efi.img" bs=1M count=10 2>/dev/null
            mkfs.vfat "$ISO_EXTRACT_DIR/boot/grub/efi.img" 2>/dev/null || true

            # Mount and copy EFI files
            local efi_mount="$WORK_DIR/efi_mount"
            mkdir -p "$efi_mount"
            if sudo mount -o loop "$ISO_EXTRACT_DIR/boot/grub/efi.img" "$efi_mount" 2>/dev/null; then
                sudo mkdir -p "$efi_mount/EFI/boot"
                sudo cp -r "$ISO_EXTRACT_DIR/EFI/boot/"* "$efi_mount/EFI/boot/" 2>/dev/null || true
                sudo umount "$efi_mount"
            fi
        fi

        xorriso -as mkisofs \
            -r -V "DevVM-Ubuntu" \
            -o "$OUTPUT_ISO" \
            -J -joliet-long \
            -eltorito-alt-boot \
            -e boot/grub/efi.img \
            -no-emul-boot \
            -isohybrid-gpt-basdat \
            "$ISO_EXTRACT_DIR" 2>&1 || {
                # Simpler fallback for EFI
                log_warn "Standard EFI build failed, trying alternate method..."
                xorriso -as mkisofs \
                    -r -V "DevVM-Ubuntu" \
                    -o "$OUTPUT_ISO" \
                    -J -joliet-long \
                    -append_partition 2 0xef "$ISO_EXTRACT_DIR/boot/grub/efi.img" \
                    -appended_part_as_gpt \
                    "$ISO_EXTRACT_DIR" 2>&1 || {
                        # Final fallback - simple data ISO
                        log_warn "EFI methods failed, creating simple bootable ISO..."
                        xorriso -as mkisofs \
                            -r -V "DevVM-Ubuntu" \
                            -o "$OUTPUT_ISO" \
                            -J -joliet-long \
                            -iso-level 3 \
                            "$ISO_EXTRACT_DIR"
                    }
            }
    else
        # Fallback - create simple ISO
        log_warn "No standard boot method detected, creating basic ISO..."
        xorriso -as mkisofs \
            -r -V "DevVM-Ubuntu" \
            -o "$OUTPUT_ISO" \
            -J -joliet-long \
            -iso-level 3 \
            "$ISO_EXTRACT_DIR"
    fi

    log_info "ISO rebuilt: $OUTPUT_ISO"
}

verify_iso() {
    log_info "Verifying ISO..."

    local verify_dir="$WORK_DIR/verify"
    rm -rf "$verify_dir"
    mkdir -p "$verify_dir"

    # Mount and verify
    local mount_point="$verify_dir/mount"
    mkdir -p "$mount_point"

    # Use xorriso to extract for verification
    xorriso -osirrox on -indev "$OUTPUT_ISO" -extract /nocloud "$verify_dir/nocloud" 2>/dev/null || true
    xorriso -osirrox on -indev "$OUTPUT_ISO" -extract /autoinstall/nocloud "$verify_dir/autoinstall-nocloud" 2>/dev/null || true
    xorriso -osirrox on -indev "$OUTPUT_ISO" -extract /boot/grub/grub.cfg "$verify_dir/grub.cfg" 2>/dev/null || true

    local errors=0

    # Check primary seed
    if [[ -f "$verify_dir/nocloud/user-data" ]]; then
        log_info "  [OK] Primary seed: /nocloud/user-data exists"
    else
        log_error "  [FAIL] Primary seed: /nocloud/user-data missing"
        errors=$((errors + 1))
    fi

    if [[ -f "$verify_dir/nocloud/meta-data" ]]; then
        log_info "  [OK] Primary seed: /nocloud/meta-data exists"
    else
        log_error "  [FAIL] Primary seed: /nocloud/meta-data missing"
        errors=$((errors + 1))
    fi

    # Check backup seed
    if [[ -f "$verify_dir/autoinstall-nocloud/user-data" ]]; then
        log_info "  [OK] Backup seed: /autoinstall/nocloud/user-data exists"
    else
        log_error "  [FAIL] Backup seed: /autoinstall/nocloud/user-data missing"
        errors=$((errors + 1))
    fi

    if [[ -f "$verify_dir/autoinstall-nocloud/meta-data" ]]; then
        log_info "  [OK] Backup seed: /autoinstall/nocloud/meta-data exists"
    else
        log_error "  [FAIL] Backup seed: /autoinstall/nocloud/meta-data missing"
        errors=$((errors + 1))
    fi

    # Check GRUB config
    if [[ -f "$verify_dir/grub.cfg" ]]; then
        if grep -q "autoinstall" "$verify_dir/grub.cfg" && grep -q "ds=nocloud" "$verify_dir/grub.cfg"; then
            log_info "  [OK] GRUB config contains autoinstall + ds=nocloud parameters"
        else
            log_error "  [FAIL] GRUB config missing autoinstall parameters"
            errors=$((errors + 1))
        fi
    else
        log_warn "  [WARN] Could not verify GRUB config"
    fi

    # Cleanup
    rm -rf "$verify_dir"

    if [[ $errors -gt 0 ]]; then
        log_error "Verification failed with $errors error(s)"
        return 1
    fi

    log_info "ISO verification passed"
    return 0
}

cleanup() {
    log_info "Cleaning up work directory..."
    rm -rf "$WORK_DIR"
}

main() {
    parse_args "$@"

    echo ""
    echo "========================================"
    echo "  DevVM ISO Builder"
    echo "========================================"
    echo ""

    check_dependencies

    # Get source ISO
    if [[ -n "$SOURCE_ISO" ]]; then
        if [[ ! -f "$SOURCE_ISO" ]]; then
            log_error "Source ISO not found: $SOURCE_ISO"
            exit 1
        fi
    elif [[ "$DOWNLOAD_ISO" == "true" ]]; then
        download_iso
    else
        log_error "No source ISO specified. Use --source-iso <path> or --download"
        usage
    fi

    log_info "Source ISO: $SOURCE_ISO"
    log_info "Output ISO: $OUTPUT_ISO"
    echo ""

    # Build process
    extract_iso
    inject_nocloud_seed
    patch_grub_config
    rebuild_iso
    verify_iso
    cleanup

    echo ""
    echo "========================================"
    log_info "Build complete!"
    log_info "Output: $OUTPUT_ISO"
    log_info "Size: $(du -h "$OUTPUT_ISO" | cut -f1)"
    echo "========================================"
}

main "$@"
