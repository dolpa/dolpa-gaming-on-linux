# Assassin's Creed Valhalla Benchmark Suite

This directory contains an automated benchmark framework for Assassin's Creed Valhalla on Linux (Steam + Proton).

It is designed for repeatable test runs across multiple graphics presets and resolutions, with structured logs and captured benchmark outputs for later analysis.

## Overview

The benchmark runner combines:

- Reproducible test definitions (single tests and groups)
- Profile-based game settings per test
- Automated game launch with Proton and environment variables
- Optional menu automation for benchmark start
- Screenshot-based result capture with OCR processing
- Standardized logs, timeout handling, and cleanup

## Automation Pipeline

```text
Config -> Profile Apply -> Launch -> Trigger -> Wait/Timeout -> Capture -> OCR/Copy -> Cleanup
```

1. Config loading
- Loads system, global, and game-specific configuration files.

2. Profile apply
- Selects and applies a profile for the requested test (resolution, quality, upscaling, RT, FG).

3. Launch
- Starts Valhalla via Proton using configured launch flags and environment variables.

4. Trigger
- Optionally uses xdotool to click through the benchmark menu.

5. Wait and timeout
- Uses timeout to enforce per-test limits and avoid hanging runs.

6. Capture and extract
- Takes result screenshots, crops result areas, preprocesses images, and runs OCR.
- Can also copy summary output from benchmark result folders when available.

7. Cleanup
- Stops helper processes, closes remaining Wine/Proton processes, and writes final logs.

## Project Layout

```text
ac-valhalla/
├── benchmark/
│   ├── run_ac-valhalla_benchmark.sh
│   ├── config/
│   │   ├── game.ac-valhalla.conf.sh
│   │   ├── tests.conf.sh
│   │   └── groups.conf.sh
│   ├── profiles/
│   ├── results/
│   └── logs/
└── README.md
```

## Requirements

Core:

- Linux system
- Bash 5+
- Steam installation with Assassin's Creed Valhalla
- Proton (GE-Proton recommended)

Required runtime tools (validated by script):

- xdotool (menu automation, when enabled)
- gnome-screenshot (result capture, when enabled)
- ffmpeg (image preprocessing)
- tesseract (OCR)
- timeout (coreutils)

Also used in default OCR flow:

- GraphicsMagick (`gm` command)

Optional:

- gamemoderun
- mangohud

## Configuration Hierarchy

The runner uses layered configuration. Later files override earlier values.

1. System-specific config:
- `system/system.<hostname>.conf.sh`

2. Global benchmark config:
- `games/etc/benchmark.config.sh`

3. Game config:
- `games/ac-valhalla/benchmark/config/game.ac-valhalla.conf.sh`

4. Environment override:
- `GAME_BENCHMARK_CONFIG=/path/to/custom.conf.sh`

## Usage

Run from the game directory:

```bash
cd games/ac-valhalla
```

Show help:

```bash
./benchmark/run_ac-valhalla_benchmark.sh --help
```

Run one test:

```bash
./benchmark/run_ac-valhalla_benchmark.sh native-1080p-high-rt-off
```

Run a group:

```bash
./benchmark/run_ac-valhalla_benchmark.sh --group quick
./benchmark/run_ac-valhalla_benchmark.sh --group dlss-comparison
```

Run all tests:

```bash
./benchmark/run_ac-valhalla_benchmark.sh --all
```

List tests and groups:

```bash
./benchmark/run_ac-valhalla_benchmark.sh --list
./benchmark/run_ac-valhalla_benchmark.sh --groups
```

Validate profile coverage:

```bash
./benchmark/run_ac-valhalla_benchmark.sh --validate-profiles
```

## Command Options

- `--help` Show usage details
- `--list` List available tests
- `--groups` List available groups
- `--group <name>` Run one named test group
- `--all` Run all tests
- `--show-test <test-name>` Show parsed test definition
- `--validate-profiles` Verify required profile files exist
- `--proton` Force Proton mode (default)
- `--native` Force native mode
- `--proton-version <version>` Override Proton version
- `--timeout-minutes <N>` Override per-test timeout
- `--gamemode` Enable gamemode wrapper
- `--mangohud` Enable MangoHud

## Test Groups

Current groups include:

- `quick`
- `native-comparison`
- `native-1080p-scaling`
- `native-1440p-scaling`
- `native-4k-scaling`
- `all-native`
- `dlss-comparison`
- `4k-upscaling`

See current definitions in `benchmark/config/groups.conf.sh`.

## Outputs

- Logs: `benchmark/logs/`
- Screenshots and extracted artifacts: `benchmark/results/`
- Copied benchmark summary files (when available): `benchmark/results/*.json`

Result filenames include test name, GPU metadata tag, and run timestamp for easier comparison.

## Extending and Customizing

- Add or adjust tests in `benchmark/config/tests.conf.sh`
- Add or adjust groups in `benchmark/config/groups.conf.sh`
- Tune launch/env settings in `benchmark/config/game.ac-valhalla.conf.sh`
- Implement a custom OCR/result parser in the game config and set:
   - `CUSTOM_EXTRACT_BENCHMARK_RESULTS_FROM_SCREENSHOTS_FUNCTION`

## Notes

- Run the game manually at least once before benchmarking so settings and compatdata paths exist.
- For reliable comparisons, keep driver version, Proton version, and background load stable between runs.
