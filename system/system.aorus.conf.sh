#!/usr/bin/env bash
# Copy this file to `system/system.<SYSTEM_NAME>.conf.sh` and edit values for your machine.

STEAM_PATH="${HOME}/.local/share/Steam"
STEAM_ROOT="${HOME}/.steam/root"
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"
PROTON_VERSION="GE-Proton10-25"

ENABLE_MANGOHUD=1
ENABLE_GAMEMODERUN=0

BENCHMARK_TIMEOUT_MINUTES=15
BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS=30

# Optional explicit path overrides:
# USER_SETTINGS_FOLDER="/path/to/.../AppData/Local/CD Projekt Red/Cyberpunk 2077"
# BENCHMARK_RESULTS_SOURCE_DIR="/path/to/.../benchmarkResults/"
# BENCHMARK_RESULTS_OUTPUT_DIR="/path/to/benchmark/results"
