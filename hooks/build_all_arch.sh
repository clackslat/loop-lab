#!/usr/bin/env bash
# Build Noble disk images for every architecture listed in arch_info.sh
# This script enables parallel building of disk images for multiple architectures
# while ensuring proper resource isolation and error handling.

# --------------------------------------------------------------------------
# Common tracing / strict settings
# --------------------------------------------------------------------------
source ./src/docker/strict_trace.sh        # sets PS4 + -euo pipefail
source ./src/docker/arch_info.sh           # provides $ARCH_LIST, maps
# --------------------------------------------------------------------------

# Function to cleanup specific loop device for an architecture
cleanup_arch_loops() {
    local arch=$1
    local start_time=$(date +%s.%N)
    echo "[build_all_arch:$arch] checking for stale loop devices..."
    if command -v docker >/dev/null 2>&1; then
        # Look for loop devices associated with our image file
        docker run --rm --privileged ubuntu:22.04 bash -c \
            "for dev in \$(losetup -nO NAME -j template-${arch}.img 2>/dev/null); do
                echo \"[build_all_arch:$arch] detaching \$dev\";
                losetup -d \$dev;
             done"
    fi
    local end_time=$(date +%s.%N)
    local duration=$(echo "$end_time - $start_time" | bc)
    echo "[build_all_arch:$arch] cleanup took $duration seconds"
}

# Clean up any stale loop devices for each architecture
# This prevents conflicts but only touches our own devices
for arch in $ARCH_LIST; do
    cleanup_arch_loops "$arch"
done

# ---------------------------------------------------------------------------
# GitHub Actions and Parallelism Control
# ---------------------------------------------------------------------------
# GitHub Actions considerations:
# 1. Resource constraints:
#    - Actions runners have limited resources (2-core CPU, 7GB RAM for Linux)
#    - Multiple Docker containers might exceed memory limits
#    - Disk I/O contention can slow parallel builds
#
# 2. Reliability concerns:
#    - Parallel builds might be less stable in CI environment
#    - Need predictable behavior for CI/CD pipelines
#    - Serial execution provides clearer logs for debugging
#
# 3. Design choices:
#    - Auto-detect GitHub Actions environment
#    - Force serial mode in Actions for reliability
#    - Allow manual override for testing/debugging
#    - Keep parallel capability for local development
# ---------------------------------------------------------------------------

# Determine if we're running in CI (GitHub Actions)
in_github_actions="${GITHUB_ACTIONS:-false}"
# Allow override via environment variable
parallel_builds="${PARALLEL_BUILDS:-true}"

# Enforce serial builds in GitHub Actions environment
if [ "$in_github_actions" = "true" ]; then
    echo "[build_all_arch] Running in GitHub Actions, enforcing serial builds"
    parallel_builds="false"
fi

# ---------------------------------------------------------------------------
# Build Process Management
# ---------------------------------------------------------------------------
# Process tracking and execution strategy:
# 1. Parallel mode (local development):
#    - Each architecture builds in separate subshell
#    - PIDs tracked for monitoring and cleanup
#    - All builds complete before reporting status
#
# 2. Serial mode (GitHub Actions/optional):
#    - One architecture at a time
#    - Immediate failure on any error
#    - Clearer logs and resource management
#
# 3. Error handling:
#    - Parallel: collect all failures before exit
#    - Serial: fail fast on first error
#    - Both: ensure proper cleanup
# ---------------------------------------------------------------------------

# Array to track Process IDs of parallel builds
pids=()

# Build function that can run either in parallel or serial
build_arch() {
    local arch=$1
    echo "[build_all_arch:$arch] building image..."
    ARCH=$arch bash src/docker/run_in_docker.sh
    local result=$?
    echo "[build_all_arch:$arch] build complete ✓"
    return $result
}

# Start builds for each architecture
for ARCH in $ARCH_LIST; do
    echo "[build_all_arch] starting build for $ARCH …"
    if [ "$parallel_builds" = "true" ]; then
        # Parallel execution in subshell
        (build_arch "$ARCH") &
        pids+=($!)
    else
        # Serial execution
        if ! build_arch "$ARCH"; then
            echo "[build_all_arch] ❌ build failed for $ARCH"
            exit 1
        fi
    fi
done

# If running in parallel, wait for all background processes
if [ "$parallel_builds" = "true" ]; then
    # Track overall success - fails if any build fails
    success=true
    for pid in "${pids[@]}"; do
        if ! wait $pid; then
            success=false
            echo "[build_all_arch] build process $pid failed!"
        fi
    done

    # Report final status for parallel builds
    # Even if some builds fail, we wait for all to complete before exiting
    # This ensures proper cleanup across all builds
    if $success; then
        echo "[build_all_arch] ✅  all architectures built successfully."
    else
        echo "[build_all_arch] ❌  some builds failed!"
        exit 1
    fi
else
    # For serial builds, we've already handled failures above
    echo "[build_all_arch] ✅  all architectures built successfully."
fi
