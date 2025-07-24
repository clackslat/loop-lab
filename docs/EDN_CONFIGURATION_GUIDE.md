# EDN-Driven Configuration System Guide

## Overview

This document describes the EDN-driven configuration system implemented in loop-lab v2.0.0, which provides a centralized, clean architecture for managing build configuration, external resources, and Docker containerization.

## Architecture

### Core Principles

1. **Single Source of Truth**: All configuration lives in `external_resources.edn`
2. **Clean Docker Separation**: Container has no knowledge of host cache structure
3. **Device Access**: Proper `/dev` volume mount for loop device operations
4. **Configuration Flow**: EDN → Babashka → Makefile → Environment Variables → Docker

### Configuration Flow

```
external_resources.edn
    ↓ (parsed by)
Babashka Functions (external_resources.bb)
    ↓ (called by)
Makefile (dynamic variable assignment)
    ↓ (environment variables)
Docker Container (build_image.sh)
    ↓ (creates)
Disk Images (build/images/)
```

## File Structure

```
loop-lab/
├── external_resources.edn         # Central configuration
├── external_resources.bb          # Babashka config functions
├── Makefile                        # Build orchestration
├── src/docker/
│   ├── build_image.sh             # Docker image builder
│   ├── Dockerfile                 # Container definition
│   ├── prep_cache.sh              # Cache management
│   ├── clean_cache.sh             # Cache cleanup
│   └── show_cache_status.sh       # Cache inspection
├── build/
│   ├── cache/                     # External resource cache
│   └── images/                    # Built disk images
└── docs/
    └── EDN_CONFIGURATION_GUIDE.md # This file
```

## Configuration Files

### 1. external_resources.edn

**Purpose**: Central configuration for all build parameters and external resources.

**Key Sections**:
- `:meta` - Version and metadata
- `:build` - Build-time paths and settings
- `:x64` / `:aarch64` - Architecture-specific resources

**Example Structure**:
```clojure
{:meta {:version "2.0.0"}
 :build {:output-dir "/output"
         :image-size "10G"
         :image-name-template "template-{arch}.img"}
 :x64 {:boot {:shell {...}}
       :os {...}}
 :aarch64 {:boot {:shell {...}}
           :os {...}}}
```

### 2. external_resources.bb

**Purpose**: Babashka functions to extract configuration values from EDN.

**Key Functions**:
- `image-path [arch]` - Returns full image path for architecture
- `image-size []` - Returns configured image size
- `cache-status [arch resource-type]` - Check cache status

**Usage**:
```bash
./external_resources.bb image-path x64    # → "/output/template-x64.img"
./external_resources.bb image-size        # → "10G"
```

### 3. Makefile

**Purpose**: Build orchestration with EDN-driven configuration.

**Key Features**:
- Dynamic variable assignment from Babashka functions
- Cache management integration
- Docker volume mounts for `/dev`, cache, and output
- Environment variable passing to containers

**Usage**:
```bash
make image ARCH=x64        # Build x64 image
make clean                 # Clean build outputs
make cache-status ARCH=x64 # Show cache status
```

## Usage Instructions

### Building Images

1. **Build for x64**:
   ```bash
   make image ARCH=x64
   ```

2. **Build for aarch64**:
   ```bash
   make image ARCH=aarch64
   ```

3. **Clean build outputs**:
   ```bash
   make clean
   ```

### Cache Management

1. **View cache status**:
   ```bash
   make cache-status ARCH=x64
   # or
   src/docker/show_cache_status.sh x64
   ```

2. **Clean specific cache**:
   ```bash
   src/docker/clean_cache.sh x64 boot    # Clean x64 boot cache
   src/docker/clean_cache.sh x64 os      # Clean x64 OS cache
   src/docker/clean_cache.sh all         # Clean all caches
   ```

3. **Prepare cache**:
   ```bash
   src/docker/prep_cache.sh x64          # Download/prepare x64 resources
   ```

### Configuration Testing

1. **Test Babashka functions**:
   ```bash
   cd src/docker
   ./external_resources.bb image-path x64
   ./external_resources.bb image-size
   ```

2. **Validate EDN syntax**:
   ```bash
   cd src/docker
   bb -e "(require '[clojure.edn :as edn]) (edn/read-string (slurp \"external_resources.edn\"))"
   ```

## Development Workflow

### Adding New External Resources

1. **Update external_resources.edn**:
   ```clojure
   :x64 {:boot {:shell {...}}
         :firmware {:edk2 {;; new resource definition
                          {:vendor {...}
                           :name "..."
                           :version {...}}
                          {:source {:url "..."}
                           :cache {...}}}}}
   ```

2. **Update cache scripts** if needed for new resource types

3. **Test configuration**:
   ```bash
   ./external_resources.bb cache-status x64 firmware
   ```

### Modifying Build Parameters

1. **Edit `:build` section in external_resources.edn**:
   ```clojure
   :build {:output-dir "/output"
           :image-size "20G"           ; ← Change size
           :new-parameter "value"}     ; ← Add parameters
   ```

2. **Add Babashka function** in external_resources.bb if needed:
   ```clojure
   (defn new-parameter []
     (get-in config [:build :new-parameter]))
   ```

3. **Update Makefile** to use new values:
   ```makefile
   NEW_PARAM_FROM_EDN := $(shell cd src/docker && ./external_resources.bb new-parameter)
   ```

## Troubleshooting

### Common Issues

1. **Loop device permission errors**:
   - Ensure Docker has `/dev` volume mount
   - Check `--privileged` flag if needed

2. **Cache download failures**:
   - Check internet connectivity
   - Verify URLs in external_resources.edn
   - Clean and retry: `src/docker/clean_cache.sh all`

3. **Configuration syntax errors**:
   - Validate EDN with Babashka
   - Check matching braces and brackets

4. **Build failures**:
   - Clean everything: `make clean && src/docker/clean_cache.sh all`
   - Rebuild from scratch: `make image ARCH=x64`

### Debug Commands

```bash
# Check git status
git status
git log --oneline -10

# Verify configuration
cd src/docker && ./external_resources.bb image-path x64

# Check Docker build
docker images | grep loop-lab

# Inspect cache
find build/cache -name "*.efi" -o -name "*.tar.xz"

# Check build outputs
ls -la build/images/
```

## Implementation Details

### Docker Architecture

- **Base Image**: Ubuntu 22.04
- **Tools**: util-linux, gdisk, dosfstools, e2fsprogs, curl, babashka
- **Volumes**: 
  - `/dev:/dev` (device access)
  - `$(PWD)/build/cache:/cache` (cache persistence)
  - `$(PWD)/build/images:/output` (build outputs)

### Environment Variables

The Makefile sets these environment variables for the Docker container:

- `IMG_PATH` - Full path to output image file
- `IMG_SIZE` - Image size (e.g., "10G")
- `ARCH` - Target architecture
- `BOOT_ARCH` - Boot architecture mapping
- `OS_ARCH` - OS architecture mapping

### Cache Strategy

- **Location**: `build/cache/{arch}/{type}/{vendor}/{variant}/`
- **Persistence**: Survives `make clean`, removed by `clean_cache.sh`
- **Validation**: SHA256 checksums (future enhancement)
- **Efficiency**: Downloads only when missing

## Version History

- **v2.0.0-edn-config**: Initial EDN-driven configuration system
  - Centralized external_resources.edn
  - Babashka integration
  - Clean Docker architecture
  - Loop device support
  - Complete build reproducibility

## Best Practices

1. **Always validate EDN syntax** before committing changes
2. **Test builds from clean state** to ensure reproducibility
3. **Use semantic versioning** for configuration schema changes
4. **Document new resource types** in this guide
5. **Keep cache management scripts updated** with new resource types

## Future Enhancements

- [ ] SHA256 checksum validation for cached resources
- [ ] Parallel downloads for multiple architectures
- [ ] Configuration schema validation
- [ ] Build artifact signing
- [ ] Cross-architecture build support
- [ ] Resource version upgrade automation
