#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# test_local_boot.sh – Automated local boot test using expect
# -----------------------------------------------------------------------------
# This script tests the local boot functionality:
# 1. Starts QEMU with the iSCSI-ready image
# 2. Uses expect to automate the boot process
# 3. Validates successful boot to login prompt
# 4. Performs basic system checks
#
# Usage:
#   ./test_local_boot.sh [architecture]
#   Example: ./test_local_boot.sh x64
# -----------------------------------------------------------------------------

set -euox pipefail

# Configuration
ARCH=${1:-x64}
DEBUG=${2:-0}  # Debug mode: 0=normal, 1=debug, 2=direct QEMU
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMG_PATH="$PROJECT_ROOT/template-${ARCH}.img"
TIMEOUT=300  # 5 minutes timeout

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $*"
}

log_success() {
    echo -e "${GREEN}[PASS]${NC} $*"
}

log_warning() {
    echo -e "${YELLOW}[WARN]${NC} $*"
}

log_error() {
    echo -e "${RED}[FAIL]${NC} $*"
}

# Check dependencies
check_dependencies() {
    local missing_deps=()
    
    # Check for expect
    if ! command -v expect >/dev/null 2>&1; then
        missing_deps+=("expect")
    fi
    
    # Check for QEMU
    local qemu_binary
    case "$ARCH" in
        "x64")
            qemu_binary="qemu-system-x86_64"
            ;;
        "aarch64")
            qemu_binary="qemu-system-aarch64"
            ;;
        *)
            log_error "Unsupported architecture: $ARCH"
            exit 1
            ;;
    esac
    
    if ! command -v "$qemu_binary" >/dev/null 2>&1; then
        missing_deps+=("$qemu_binary")
    fi
    
    # Check for image file
    if [[ ! -f "$IMG_PATH" ]]; then
        log_error "Image file not found: $IMG_PATH"
        log_info "Please build the image first with: make build-x64"
        exit 1
    fi
    
    # Check for UEFI firmware (only needed for x64)
    if [[ "$ARCH" == "x64" ]]; then
        local firmware_path="/opt/homebrew/share/qemu/edk2-x86_64-code.fd"
        if [[ ! -f "$firmware_path" ]]; then
            log_error "UEFI firmware not found: $firmware_path"
            log_info "Please install QEMU with UEFI support: brew install qemu"
            exit 1
        fi
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: brew install expect qemu"
        exit 1
    fi
    
    log_success "All dependencies found"
}

# Make sure the script is executable
ensure_expect_script_executable() {
    # Try the simple boot test first, fall back to the full boot test if needed
    local expect_script="$SCRIPT_DIR/simple_boot_test.exp"
    local fallback_script="$SCRIPT_DIR/boot_test.exp"
    
    if [[ ! -f "$expect_script" ]]; then
        log_warning "Simple expect script not found: $expect_script"
        log_info "Falling back to full boot test script"
        
        if [[ ! -f "$fallback_script" ]]; then
            log_error "Fallback script not found: $fallback_script"
            exit 1
        fi
        
        expect_script="$fallback_script"
    fi
    
    if [[ ! -x "$expect_script" ]]; then
        log_info "Making expect script executable"
        chmod +x "$expect_script"
    fi
    
    echo "$expect_script"
}

# Run the local boot test
run_local_boot_test() {
    log_info "Starting local boot test for $ARCH architecture..."
    log_info "Image: $IMG_PATH"
    log_info "Timeout: ${TIMEOUT}s"
    
    # Get the appropriate expect script and ensure it's executable
    local expect_script=$(ensure_expect_script_executable)
    
    log_info "Using expect script: $expect_script"
    log_info "You can run this script manually with: $expect_script \"$IMG_PATH\" \"$ARCH\""
    
    # Run the test
    log_info "Launching QEMU with expect automation..."
    log_info "NOTE: All output will be displayed AND saved to /tmp/test_local_boot_${ARCH}_output.log"
    echo "========================================="
    echo "Boot Test Output"
    echo "========================================="
    
    echo "Running expect script: $expect_script \"$IMG_PATH\" \"$ARCH\""
    echo ""
    
    # Execute the script directly so we can see all output
    # Use tee to capture output while still displaying it
    if "$expect_script" "$IMG_PATH" "$ARCH" 2>&1 | tee /tmp/test_local_boot_${ARCH}_output.log; then
        log_success "Local boot test PASSED!"
        echo ""
        echo "🎉 Key validations completed:"
        echo "  ✓ UEFI Shell startup"
        echo "  ✓ Boot script execution"
        echo "  ✓ Kernel loading and boot"
        echo "  ✓ System login"
        echo "  ✓ iSCSI components present"
        echo "  ✓ Clean shutdown"
        echo ""
        return 0
    else
        log_error "Local boot test FAILED!"
        echo ""
        echo "❌ Test failed - check output above for details"
        echo ""
        log_info "Detailed output log saved to /tmp/test_local_boot_${ARCH}_output.log"
        return 1
    fi
}

# Clean up function
cleanup() {
    log_info "Preserving expect script and output log for debugging..."
    log_info "Script: /tmp/test_local_boot_${ARCH}.exp"
    log_info "Log: /tmp/test_local_boot_${ARCH}_output.log"
    # Don't delete the expect script so we can run it manually
    # rm -f /tmp/test_local_boot_*.exp /tmp/test_local_boot_*_output.log
}

# Run QEMU directly for debugging
run_qemu_direct() {
    log_info "Running QEMU directly for $ARCH architecture (Debug Mode)"
    log_info "Image: $IMG_PATH"
    
    if [[ "$ARCH" == "aarch64" ]]; then
        log_info "Running command: qemu-system-aarch64 -machine virt,accel=hvf -cpu host -smp 4 -m 4096 -bios /opt/homebrew/opt/qemu/share/qemu/edk2-aarch64-code.fd -drive if=virtio,format=raw,file=$IMG_PATH -serial mon:stdio"
        qemu-system-aarch64 \
            -machine virt,accel=hvf \
            -cpu host -smp 4 -m 4096 \
            -bios /opt/homebrew/opt/qemu/share/qemu/edk2-aarch64-code.fd \
            -drive if=virtio,format=raw,file="$IMG_PATH" \
            -serial mon:stdio
    else
        log_info "Running command: qemu-system-x86_64 -accel tcg -machine q35 -cpu qemu64 -m 1024 -device virtio-rng-pci -nographic -no-reboot -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-x86_64-code.fd -drive if=virtio,format=raw,file=$IMG_PATH"
        qemu-system-x86_64 \
            -accel tcg \
            -machine q35 \
            -cpu qemu64 \
            -m 1024 \
            -device virtio-rng-pci \
            -nographic \
            -no-reboot \
            -drive if=pflash,format=raw,readonly=on,file=/opt/homebrew/share/qemu/edk2-x86_64-code.fd \
            -drive if=virtio,format=raw,file="$IMG_PATH"
    fi
}

# Main function
main() {
    echo "========================================="
    echo "Loop-lab Automated Local Boot Test"
    echo "========================================="
    echo "Architecture: $ARCH"
    echo "Image: $IMG_PATH"
    echo "Debug Mode: $DEBUG"
    echo "Timestamp: $(date)"
    echo "========================================="
    
    # Set up cleanup trap
    trap cleanup EXIT
    
    # Check dependencies first
    check_dependencies
    
    # Run in direct QEMU mode if requested
    if [[ "$DEBUG" == "2" ]]; then
        run_qemu_direct
        return $?
    fi
    
    # Run the test
    if run_local_boot_test; then
        log_success "All tests completed successfully!"
        exit 0
    else
        log_error "Test suite failed!"
        exit 1
    fi
}

# Run main function
main "$@"
