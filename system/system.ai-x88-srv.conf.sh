#!/usr/bin/env bash
# Copy this file to `system/system.<SYSTEM_NAME>.conf.sh` and edit values for your machine.

STEAM_PATH="${HOME}/.local/share/Steam"             # Main Steam installation
STEAM_ROOT="${HOME}/.steam/root"                    # Alternative Steam root path
CUSTOM_LIBRARY_PATH="/mnt/VMData/Steam Library"         # Custom Steam library path
PROTON_VERSION="GE-Proton9-27"

ENABLE_MANGOHUD=0
ENABLE_GAMEMODERUN=0

BENCHMARK_TIMEOUT_MINUTES=15
BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS=30

# Optional explicit path overrides:
# USER_SETTINGS_FOLDER="/path/to/.../AppData/Local/CD Projekt Red/Cyberpunk 2077"
# BENCHMARK_RESULTS_SOURCE_DIR="/path/to/.../benchmarkResults/"
# BENCHMARK_RESULTS_OUTPUT_DIR="/path/to/benchmark/results"
