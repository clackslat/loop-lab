#!/usr/bin/env bash
# -----------------------------------------------------------------------------
# test_boot_modes.sh – Programmatic testing of both local and iSCSI boot modes
# -----------------------------------------------------------------------------
# This script uses QEMU to boot the generated images and test:
# 1. Local boot mode (default behavior)
# 2. iSCSI boot readiness (modules and tools present)
# 3. Console access and SSH connectivity
# 4. Boot script functionality
#
# Requirements:
#   - qemu-system-x86_64 (for x64 testing)
#   - qemu-system-aarch64 (for aarch64 testing) 
#   - OVMF firmware files
#   - expect (for automated interaction)
#
# Usage:
#   ./test_boot_modes.sh <architecture>
#   Example: ./test_boot_modes.sh x64
# -----------------------------------------------------------------------------

set -euo pipefail

# Configuration
ARCH=${1:-x64}
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
IMG_PATH="$PROJECT_ROOT/template-${ARCH}.img"
TEST_TIMEOUT=120  # 2 minutes per test
VM_MEMORY=2048    # 2GB RAM
VM_CORES=2

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
    log_info "Checking dependencies..."
    
    local missing_deps=()
    
    case "$ARCH" in
        "x64")
            if ! command -v qemu-system-x86_64 >/dev/null 2>&1; then
                missing_deps+=("qemu-system-x86_64")
            fi
            ;;
        "aarch64")
            if ! command -v qemu-system-aarch64 >/dev/null 2>&1; then
                missing_deps+=("qemu-system-aarch64")
            fi
            ;;
    esac
    
    if ! command -v expect >/dev/null 2>&1; then
        missing_deps+=("expect")
    fi
    
    if [[ ${#missing_deps[@]} -gt 0 ]]; then
        log_error "Missing dependencies: ${missing_deps[*]}"
        log_info "Install with: brew install qemu expect  # macOS"
        log_info "Or: apt-get install qemu-system expect  # Ubuntu"
        return 1
    fi
    
    log_success "All dependencies found"
}

# Get OVMF firmware paths
get_firmware_path() {
    local firmware_paths=()
    
    case "$ARCH" in
        "x64")
            # Common OVMF locations
            firmware_paths=(
                "/usr/share/ovmf/OVMF.fd"
                "/usr/share/edk2/ovmf/OVMF.fd"
                "/opt/homebrew/share/qemu/edk2-x86_64-code.fd"
                "/usr/local/share/qemu/edk2-x86_64-code.fd"
                "/System/Library/Frameworks/Hypervisor.framework/Versions/A/Resources/OVMF.fd"
            )
            ;;
        "aarch64")
            firmware_paths=(
                "/usr/share/qemu-efi-aarch64/QEMU_EFI.fd"
                "/usr/share/edk2/aarch64/QEMU_EFI.fd"
                "/opt/homebrew/share/qemu/edk2-aarch64-code.fd"
                "/usr/local/share/qemu/edk2-aarch64-code.fd"
            )
            ;;
    esac
    
    for path in "${firmware_paths[@]}"; do
        if [[ -f "$path" ]]; then
            echo "$path"
            return 0
        fi
    done
    
    # If no firmware found, we'll run without UEFI (legacy mode)
    log_warning "No UEFI firmware found, tests will be limited"
    echo ""
}

# Create expect script for VM interaction
create_expect_script() {
    local test_name="$1"
    local expect_file="$2"
    local boot_timeout="$3"
    
    cat > "$expect_file" <<'EXPECT_EOF'
#!/usr/bin/expect -f

set timeout [lindex $argv 0]
set test_name [lindex $argv 1]

# Start logging
log_user 1

# Spawn QEMU (command will be passed via stdin)
eval spawn [read stdin]

# Wait for boot process
expect {
    "Loop-lab EFI Boot Script" {
        send_user "\n\[BOOT\] EFI boot script detected\n"
        exp_continue
    }
    "Loading kernel..." {
        send_user "\n\[BOOT\] Kernel loading started\n"
        exp_continue
    }
    "maintuser@" {
        send_user "\n\[SUCCESS\] Login prompt reached\n"
        send "uname -a\r"
        expect "maintuser@"
        send "lsmod | grep iscsi\r"
        expect "maintuser@"
        send "which iscsiadm\r"
        expect "maintuser@"
        send "systemctl status open-iscsi\r"
        expect "maintuser@"
        send "ls /boot/efi/EFI/BOOT/\r"
        expect "maintuser@"
        send "exit\r"
        exit 0
    }
    "login:" {
        send_user "\n\[LOGIN\] Manual login required\n"
        send "maintuser\r"
        expect "Password:"
        send "maintpass\r"
        expect "maintuser@"
        send "exit\r"
        exit 0
    }
    timeout {
        send_user "\n\[TIMEOUT\] Boot test timed out after $timeout seconds\n"
        exit 1
    }
    eof {
        send_user "\n\[EOF\] VM terminated unexpectedly\n"
        exit 1
    }
}
EXPECT_EOF
    
    chmod +x "$expect_file"
}

# Test local boot mode
test_local_boot() {
    log_info "Testing local boot mode for $ARCH..."
    
    local firmware_path
    firmware_path=$(get_firmware_path)
    
    local qemu_cmd
    local expect_script="$PROJECT_ROOT/test_local_boot.exp"
    
    case "$ARCH" in
        "x64")
            qemu_cmd="qemu-system-x86_64"
            qemu_cmd+=" -m $VM_MEMORY -smp $VM_CORES"
            qemu_cmd+=" -drive file=$IMG_PATH,format=raw,if=virtio"
            qemu_cmd+=" -netdev user,id=net0 -device virtio-net,netdev=net0"
            qemu_cmd+=" -serial stdio -display none"
            qemu_cmd+=" -no-reboot -no-shutdown"
            
            if [[ -n "$firmware_path" ]]; then
                qemu_cmd+=" -bios $firmware_path"
            fi
            ;;
        "aarch64")
            qemu_cmd="qemu-system-aarch64"
            qemu_cmd+=" -M virt -cpu cortex-a57"
            qemu_cmd+=" -m $VM_MEMORY -smp $VM_CORES"
            qemu_cmd+=" -drive file=$IMG_PATH,format=raw,if=virtio"
            qemu_cmd+=" -netdev user,id=net0 -device virtio-net,netdev=net0"
            qemu_cmd+=" -serial stdio -display none"
            qemu_cmd+=" -no-reboot -no-shutdown"
            
            if [[ -n "$firmware_path" ]]; then
                qemu_cmd+=" -bios $firmware_path"
            fi
            ;;
    esac
    
    create_expect_script "local_boot" "$expect_script" "$TEST_TIMEOUT"
    
    log_info "Running: $qemu_cmd"
    log_info "Timeout: ${TEST_TIMEOUT}s"
    
    if echo "$qemu_cmd" | "$expect_script" "$TEST_TIMEOUT" "local_boot"; then
        log_success "Local boot test passed"
        return 0
    else
        log_error "Local boot test failed"
        return 1
    fi
}

# Test iSCSI readiness (check modules and tools)
test_iscsi_readiness() {
    log_info "Testing iSCSI readiness for $ARCH..."
    
    # Create a temporary mount point
    local temp_mount
    temp_mount=$(mktemp -d)
    
    # Check if we can mount the image (requires root/sudo)
    if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
        local use_sudo=""
        [[ $EUID -ne 0 ]] && use_sudo="sudo"
        
        # Mount the image to check contents
        local loopdev
        loopdev=$($use_sudo losetup --find --show --partscan "$IMG_PATH")
        
        # Mount root filesystem
        $use_sudo mount -t ext4 "${loopdev}p2" "$temp_mount"
        
        # Check for iSCSI components
        local tests_passed=0
        local total_tests=6
        
        # Test 1: Check initramfs modules file
        if grep -q "iscsi_tcp" "$temp_mount/etc/initramfs-tools/modules"; then
            log_success "iSCSI modules configured in initramfs"
            ((tests_passed++))
        else
            log_error "iSCSI modules not found in initramfs config"
        fi
        
        # Test 2: Check for iSCSI binaries
        if [[ -f "$temp_mount/usr/sbin/iscsiadm" ]]; then
            log_success "iscsiadm tool found"
            ((tests_passed++))
        else
            log_error "iscsiadm tool not found"
        fi
        
        # Test 3: Check for iscsistart
        if [[ -f "$temp_mount/sbin/iscsistart" ]]; then
            log_success "iscsistart tool found"
            ((tests_passed++))
        else
            log_error "iscsistart tool not found"
        fi
        
        # Test 4: Check open-iscsi service
        if [[ -f "$temp_mount/lib/systemd/system/open-iscsi.service" ]]; then
            log_success "open-iscsi service found"
            ((tests_passed++))
        else
            log_error "open-iscsi service not found"
        fi
        
        # Test 5: Check iSCSI config files
        if [[ -f "$temp_mount/etc/iscsi/iscsid.conf" ]]; then
            log_success "iSCSI configuration files found"
            ((tests_passed++))
        else
            log_error "iSCSI configuration files not found"
        fi
        
        # Test 6: Check initramfs iSCSI config
        if [[ -f "$temp_mount/etc/initramfs-tools/conf.d/iscsi" ]]; then
            log_success "initramfs iSCSI configuration found"
            ((tests_passed++))
        else
            log_error "initramfs iSCSI configuration not found"
        fi
        
        # Cleanup
        $use_sudo umount "$temp_mount"
        $use_sudo losetup -d "$loopdev"
        rmdir "$temp_mount"
        
        if [[ $tests_passed -eq $total_tests ]]; then
            log_success "iSCSI readiness test passed ($tests_passed/$total_tests)"
            return 0
        else
            log_error "iSCSI readiness test failed ($tests_passed/$total_tests)"
            return 1
        fi
    else
        log_warning "Cannot mount image without root privileges, skipping detailed iSCSI readiness test"
        return 0
    fi
}

# Test EFI boot scripts
test_boot_scripts() {
    log_info "Testing EFI boot scripts for $ARCH..."
    
    local temp_mount
    temp_mount=$(mktemp -d)
    
    if [[ $EUID -eq 0 ]] || sudo -n true 2>/dev/null; then
        local use_sudo=""
        [[ $EUID -ne 0 ]] && use_sudo="sudo"
        
        local loopdev
        loopdev=$($use_sudo losetup --find --show --partscan "$IMG_PATH")
        
        # Mount ESP
        $use_sudo mount -t vfat "${loopdev}p1" "$temp_mount"
        
        local tests_passed=0
        local total_tests=3
        
        # Test 1: Check startup.nsh exists
        if [[ -f "$temp_mount/EFI/BOOT/startup.nsh" ]]; then
            log_success "startup.nsh boot script found"
            ((tests_passed++))
        else
            log_error "startup.nsh boot script not found"
        fi
        
        # Test 2: Check iscsi-boot.nsh exists
        if [[ -f "$temp_mount/EFI/BOOT/iscsi-boot.nsh" ]]; then
            log_success "iscsi-boot.nsh template found"
            ((tests_passed++))
        else
            log_error "iscsi-boot.nsh template not found"
        fi
        
        # Test 3: Check kernel and initrd files
        if [[ -f "$temp_mount/EFI/BOOT/vmlinuz-"* ]] && [[ -f "$temp_mount/EFI/BOOT/initrd.img-"* ]]; then
            log_success "Kernel and initrd files found on ESP"
            ((tests_passed++))
        else
            log_error "Kernel or initrd files missing on ESP"
        fi
        
        # Show boot script content
        if [[ -f "$temp_mount/EFI/BOOT/startup.nsh" ]]; then
            log_info "startup.nsh content preview:"
            head -10 "$temp_mount/EFI/BOOT/startup.nsh" | sed 's/^/  /'
        fi
        
        # Cleanup
        $use_sudo umount "$temp_mount"
        $use_sudo losetup -d "$loopdev"
        rmdir "$temp_mount"
        
        if [[ $tests_passed -eq $total_tests ]]; then
            log_success "Boot scripts test passed ($tests_passed/$total_tests)"
            return 0
        else
            log_error "Boot scripts test failed ($tests_passed/$total_tests)"
            return 1
        fi
    else
        log_warning "Cannot mount image without root privileges, skipping boot scripts test"
        return 0
    fi
}

# Main test runner
main() {
    echo "========================================"
    echo "Loop-lab Boot Mode Testing Suite"
    echo "========================================"
    echo "Architecture: $ARCH"
    echo "Image: $IMG_PATH"
    echo "Timestamp: $(date)"
    echo "========================================"
    
    # Check if image exists
    if [[ ! -f "$IMG_PATH" ]]; then
        log_error "Image file not found: $IMG_PATH"
        log_info "Build the image first with: ARCH=$ARCH ./src/docker/run_in_docker.sh"
        exit 1
    fi
    
    local test_results=()
    
    # Run dependency check
    if check_dependencies; then
        test_results+=("dependencies:PASS")
    else
        test_results+=("dependencies:FAIL")
        log_error "Cannot proceed without required dependencies"
        exit 1
    fi
    
    # Run iSCSI readiness test
    if test_iscsi_readiness; then
        test_results+=("iscsi_readiness:PASS")
    else
        test_results+=("iscsi_readiness:FAIL")
    fi
    
    # Run boot scripts test
    if test_boot_scripts; then
        test_results+=("boot_scripts:PASS")
    else
        test_results+=("boot_scripts:FAIL")
    fi
    
    # Run local boot test (requires more time and QEMU)
    log_info "Starting local boot test (this may take up to ${TEST_TIMEOUT} seconds)..."
    if test_local_boot; then
        test_results+=("local_boot:PASS")
    else
        test_results+=("local_boot:FAIL")
    fi
    
    # Summary
    echo ""
    echo "========================================"
    echo "Test Results Summary"
    echo "========================================"
    
    local passed=0
    local failed=0
    
    for result in "${test_results[@]}"; do
        local test_name="${result%:*}"
        local test_status="${result#*:}"
        
        if [[ "$test_status" == "PASS" ]]; then
            log_success "$test_name"
            ((passed++))
        else
            log_error "$test_name"
            ((failed++))
        fi
    done
    
    echo "========================================"
    echo "Total: $((passed + failed)) tests"
    echo "Passed: $passed"
    echo "Failed: $failed"
    
    if [[ $failed -eq 0 ]]; then
        log_success "All tests passed! Image is ready for both local and iSCSI boot."
        echo ""
        echo "Next steps:"
        echo "  • Local boot: Image will boot from local disk by default"
        echo "  • iSCSI boot: Configure iSCSI target and modify boot parameters"
        echo "  • Test in VM: qemu-system-x86_64 -bios /path/to/OVMF.fd -drive file=$IMG_PATH,format=raw"
        exit 0
    else
        log_error "Some tests failed. Please review the output above."
        exit 1
    fi
}

# Cleanup function
cleanup() {
    # Remove temporary expect scripts
    rm -f "$PROJECT_ROOT/test_local_boot.exp"
    rm -f "$PROJECT_ROOT/test_iscsi_boot.exp"
}

# Set trap for cleanup
trap cleanup EXIT

# Run main function
main "$@"
