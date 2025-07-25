# Source Control Management

Infrastructure component for Git hooks and repository management tools.

> **🔗 Related**: [Main Project Documentation](../../README.md) | [Docker Environment](../docker/README.md)

## Components

- **[`pre-commit`](src/pre-commit)** - Git pre-commit hook for code quality enforcement
- **[`build_all_arch.sh`](src/build_all_arch.sh)** - Multi-architecture build automation
- **[`find_shell_scripts.sh`](src/find_shell_scripts.sh)** - Shell script discovery and validation

## Git Hooks

### Pre-commit Hook
Automatically runs checks before commits:
- Shell script validation with shellcheck
- Code formatting verification
- Build system consistency checks

### Setup
```bash
git config core.hooksPath infra/scm/src
```

## Build Automation

### Multi-Architecture Builds
The [`build_all_arch.sh`](src/build_all_arch.sh) script automates building for all supported architectures:
```bash
./[build_all_arch.sh](src/build_all_arch.sh)
```

### Script Discovery
The [`find_shell_scripts.sh`](src/find_shell_scripts.sh) utility helps locate and validate shell scripts across the project:
```bash
./[find_shell_scripts.sh](src/find_shell_scripts.sh)
```

## Integration

SCM tools integrate with the main build system to ensure:
- Code quality consistency
- Multi-architecture compatibility
- Repository hygiene
