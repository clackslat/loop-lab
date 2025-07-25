# Docker Build Environment

Infrastructure component providing the containerized build environment for disk image creation.

> **🔗 Related**: [Main Project Documentation](../../README.md) | [Configuration Management](../config/README.md) | [Network Boot System](../../app/netboot/README.md)

## Components

- **[`Dockerfile`](src/Dockerfile)** - Container definition with build tools and runtime environment
- **[`strict_trace.sh`](src/strict_trace.sh)** - Enhanced shell debugging and tracing utilities

## Container Features

### Base Environment
- Ubuntu 22.04 base image
- Build tools: `util-linux`, `gdisk`, `dosfstools`, `xz-utils`
- Babashka for configuration processing

### Installed Scripts
- Configuration management scripts from `infra/config/`
- Image assembly scripts from `app/netboot/src/assembly/`
- Debugging and tracing utilities

### Build Arguments
- `ARCH` - Target architecture (x64, aarch64)
- `BOOT_ARCH` - UEFI architecture (X64, AA64)  
- `OS_ARCH` - OS architecture (amd64, arm64)

## Usage

The Docker environment is automatically managed by the main build system:

```bash
# Build container image
make docker-build

# Force rebuild container
make docker-rebuild

# Show container information
make docker-info
```

## Development

For manual container interaction:
```bash
# Run interactively
docker run -it --privileged \
  -v "$(pwd)/build:/output" \
  -v "$(pwd)/build/cache:/cache" \
  loop-lab-builder:latest bash
```

## Requirements

- Privileged Docker execution for loop device access
- Host volume mounts for build output and cache
