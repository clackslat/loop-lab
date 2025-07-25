# Loop Lab

A containerized network boot disk image builder with infrastructure/application separation.

## Project Structure

The project follows a clean separation between infrastructure concerns and application logic:

```
├── infra/                    # Infrastructure components
│   ├── config/src/          # Configuration management (EDN, external resources)
│   ├── cache-mgmt/src/      # External resource caching system
│   ├── docker/src/          # Container build environment
│   └── scm/src/             # Source control management (hooks)
├── app/                     # Application components
│   └── netboot/             # Network boot disk image creation
│       ├── src/assembly/    # Core image assembly scripts
│       └── test/            # Application tests
├── build/                   # Build artifacts and cache
│   ├── cache/              # Downloaded external resources
│   └── images/             # Generated disk images
└── docs/                   # Project documentation
```

Each functional component follows a tri-directory pattern: `docs/`, `test/`, and `src/`.

## Quick Start

### One-time setup
```bash
git config core.hooksPath infra/scm/src
```

### Build a disk image
```bash
# Build x64 image (most common)
make image ARCH=x64

# Build for other architectures
make image ARCH=aarch64
```

## Main Build Targets

### Image Building
- `make image ARCH=<arch>` - Build disk image for specific architecture
- `make images-all` - Build images for all supported architectures
- `make image-rebuild ARCH=<arch>` - Force rebuild (clears cache first)

### Development
- `make dev-quick` - Quick development build (use existing cache)
- `make dev-rebuild` - Full development rebuild (Docker + image)

### Docker Management
- `make docker-build` - Build container image if needed
- `make docker-rebuild` - Force rebuild container
- `make docker-info` - Show container image information

### Cache Management
- `make cache-status` - Show cache status for all architectures
- `make cache-clean ARCH=<arch>` - Clean cache for specific architecture
- `make cache-clean-all` - Clean cache for all architectures

### Cleanup
- `make clean` - Clean build artifacts (keep cache)
- `make clean-all` - Clean everything including cache

## Architecture Support

Currently supported architectures:
- `x64` - Intel/AMD 64-bit
- `aarch64` - ARM 64-bit

## Components

- **[Network Boot System](app/netboot/README.md)** - iSCSI-capable network boot disk image creation
