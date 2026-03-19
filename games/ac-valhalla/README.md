# Assassin's Creed Valhalla Benchmark Suite

This directory contains automated benchmark scripts for Assassin's Creed Valhalla.

## Overview

The benchmark suite is designed to run comprehensive performance tests on AC Valhalla with various graphics settings, upscaling technologies, and configurations.

## Key Features

- **Automated benchmark execution** with configurable test suites
- **Multiple upscaling technologies** support (DLSS, FSR, XeSS)
- **Comprehensive test groups** for systematic performance analysis
- **Screenshot capture** and OCR result extraction
- **Robust error handling** and logging
- **System configuration** support for different hardware setups

## Recent Improvements (2024)

### Enhanced Error Handling
- Fixed debug output statements left in production code
- Corrected syntax errors in configuration files
- Improved logging consistency throughout the script

### Better Use of dolpa-bash-utils
- **Configuration validation** using `env_require()` and `validate_directory()`
- **Runtime dependency checking** with better error messages
- **Signal handling** for graceful cleanup of background processes
- **Improved logging** with proper log levels and formatting

### Test Configuration
- Updated test definitions specifically for AC Valhalla
- Added comprehensive test groups for different scenarios
- Proper resolution definitions and game-specific settings

### Code Quality
- Fixed variable name bugs and logging inconsistencies
- Better command-line argument parsing with error handling
- Improved background process cleanup and resource management

## Usage

### Running Individual Tests
```bash
./benchmark/run_ac-valhalla_benchmark.sh native-1080p-high-rt-off
```

### Running Test Groups
```bash
./benchmark/run_ac-valhalla_benchmark.sh --group quick
./benchmark/run_ac-valhalla_benchmark.sh --group dlss-comparison
```

### Available Options
- `--help` - Show usage information
- `--list` - List all available tests
- `--groups` - List all test groups
- `--validate-profiles` - Validate that all test profiles exist
- `--proton` / `--native` - Choose execution mode
- `--gamemode` - Enable gamemode integration
- `--mangohud` - Enable MangoHUD overlay
- `--timeout-minutes <N>` - Set per-test timeout

### Configuration

The script uses a multi-tier configuration system:

1. **System-specific config**: `system/system.<hostname>.conf.sh`
2. **Game-specific config**: `config/game.ac-valhalla.conf.sh`
3. **Environment override**: `GAME_BENCHMARK_CONFIG` variable

## Test Groups

- **quick**: Fast comparison across resolutions
- **native-comparison**: Native rendering comparison
- **dlss-comparison**: DLSS upscaling tests
- **4k-upscaling**: 4K performance with various upscaling
- **all-native**: Complete native rendering test suite

## Dependencies

Required tools (automatically validated):
- `gnome-screenshot` (for result screenshots)
- `ffmpeg` (for image processing)
- `tesseract-ocr` (for OCR text extraction)
- `xdotool` (for menu automation)
- `timeout` (from coreutils)

Optional tools:
- `gamemode` (for performance optimization)
- `mangohud` (for performance overlay)

## File Structure

```
ac-valhalla/
├── benchmark/
│   ├── run_ac-valhalla_benchmark.sh    # Main script
│   ├── config/
│   │   ├── game.ac-valhalla.conf.sh    # Game configuration
│   │   ├── tests.conf.sh               # Test definitions
│   │   └── groups.conf.sh              # Test group definitions
│   ├── profiles/                       # Game setting profiles
│   ├── results/                        # Benchmark results
│   └── logs/                          # Execution logs
└── README.md                          # This file
```

## Contributing

When adding new tests or modifying the script:

1. Use the dolpa-bash-utils library functions for consistency
2. Follow the established logging patterns
3. Test configuration validation before deployment
4. Update test groups and documentation as needed

## System Requirements

- Linux system with Steam and Proton
- AC Valhalla installed in Steam library
- Sufficient disk space for logs and results
- Graphics drivers supporting the tested upscaling technologies