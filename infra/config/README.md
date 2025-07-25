# Configuration Management

Infrastructure component for managing external resource definitions and build configuration.

> **🔗 Related**: [Main Project Documentation](../../README.md) | [Cache Management](../cache-mgmt/README.md) | [Network Boot System](../../app/netboot/README.md)

## Components

- **`external_resources.edn`** - EDN-format configuration defining external resource URLs and cache paths
- **`external_resources.bb`** - Babashka script for processing configuration and resolving architecture-specific resources
- **`load_scripts.sh`** - Shell utility for loading and executing Babashka scripts

## External Resources

Currently managed resources:
- **UEFI Shell binaries** - Architecture-specific shell executables from pbatard/UEFI-Shell
- **Ubuntu root filesystems** - Minimal cloud images for different architectures

## Usage

The configuration system is automatically used by cache management and Docker build processes. Resources are resolved based on the target architecture (x64, aarch64).

## Configuration Format

Resources are defined in EDN with the following structure:
```clojure
{:resources
 {:boot {...}
  :os {...}}}
```

Each resource includes URL templates, cache paths, and architecture-specific mappings.
