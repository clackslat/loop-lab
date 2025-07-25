# Cache Management

Infrastructure component for downloading, storing, and managing external build resources.

## Components

- **`check_and_download_cache.sh`** - Main cache management script with download logic
- **`prep_cache.sh`** - Cache preparation for specific architectures
- **`show_cache_status.sh`** - Display current cache status across architectures
- **`clean_cache.sh`** - Cache cleanup utilities

## Cache Structure

```
build/cache/
├── x64/
│   ├── boot/shell/shell64.efi
│   └── os/ubuntu/minimal/24.04/ubuntu-24.04-minimal-cloudimg-amd64-root.tar.xz
└── aarch64/
    ├── boot/shell/shellaa64.efi
    └── os/ubuntu/minimal/24.04/ubuntu-24.04-minimal-cloudimg-arm64-root.tar.xz
```

## Features

- **Smart Caching**: Only downloads resources if missing or outdated
- **Architecture Support**: Separate cache trees for x64 and aarch64
- **Progress Reporting**: Download progress with curl
- **Integrity Checking**: Validates downloaded resources

## Usage

Cache management is automatically handled by the main build system, but can be used directly:

```bash
# Prepare cache for specific architecture
./prep_cache.sh x64

# Check cache status
./show_cache_status.sh

# Clean architecture-specific cache
./clean_cache.sh x64
```
