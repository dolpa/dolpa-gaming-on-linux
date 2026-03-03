# Shadow of the Tomb Raider (Linux/Steam Native)

Benchmark automation and profile management for Shadow of the Tomb Raider on Linux.

## What this folder contains

- `benchmark/run_sottr_benchmark.sh`
  - Runs predefined benchmark tests/groups via CLI.
  - Uses per-test profile snapshots by launch mode:
    - native: `profiles/{TEST_NAME}.preferences.xml`
    - proton: `profiles/{TEST_NAME}.preferences.user.reg`
  - Copies selected profile snapshot into live settings target before each run.
  - Copies benchmark outputs into local `benchmark/results/` with run + GPU metadata.
- `benchmark/analyze_sottr_results.sh`
  - Builds markdown reports from copied benchmark result files.
  - Supports filtering by test and/or group.
  - Adds GPU model / VRAM / driver columns to report rows.
- `benchmark/config/tests.native.conf.sh`
  - Base test catalog (non-generated test definitions).
- `benchmark/config/groups.native.conf.sh`
  - Base predefined groups.
- `benchmark/config/tests.proton.conf.sh`
  - Proton-mode test catalog (DX12 on/off + DLSS Ultra Performance presets).
- `benchmark/config/groups.proton.conf.sh`
  - Proton-mode predefined groups.
- `benchmark/profiles/`
  - Contains one profile file per test name for native and proton catalogs.
- `benchmark/results/`
  - Stores copied benchmark result files and generated markdown reports.

## Native Linux feature differences (Feral port)

This benchmark suite is intentionally native Linux focused. For the native Linux port:

- Ray Tracing is not used.
- DLSS / FSR upscaling modes are not used.
- Frame Generation is not used.
- Resolution scaling is handled by native game settings (for example Resolution Modifier), not AI upscalers.

Proton-mode tests remain available for Windows-feature benchmarking (for example DX12 toggles and DLSS Ultra Performance presets).

## Available tests and how they work

Tests come directly from:

- `benchmark/config/tests.native.conf.sh`

Native scope includes 12 tests:

- 1080p: low / medium / high / ultra (`rt-off`)
- 1440p: low / medium / high / ultra (`rt-off`)
- 4k: low / medium / high / ultra (`rt-off`)

### Test naming convention

`{mode}-{resolution}-{quality}-rt-off`

Examples:

- `native-1080p-high-rt-off`
- `native-1440p-medium-rt-off`
- `native-4k-ultra-rt-off`

### Test groups

Groups are defined in:

- `benchmark/config/groups.native.conf.sh`

Key groups:

- `quick`
- `native-comparison`
- `1080p-scaling`
- `1440p-scaling`
- `4k-scaling`
- `all-native`

## Current benchmark flow

For each test:

1. Script selects test parameters from `tests.native.conf.sh`.
2. Script copies profile by launch mode:
  - native source: `benchmark/profiles/{TEST_NAME}.preferences.xml`
  - native target: `~/.local/share/feral-interactive/Shadow of the Tomb Raider/preferences`
  - proton source: `benchmark/profiles/{TEST_NAME}.preferences.user.reg`
  - proton target: `.../steamapps/compatdata/750920/pfx/user.reg`
3. Launches benchmark (native first, Proton fallback when needed).
4. Finds latest benchmark artifacts in result source location.
5. Copies normalized result artifact(s) into:
   - `benchmark/results/`
6. Saved JSON result filename format:
   - `${GAME_ID}_result_${test_name}_${gpu_model}_${gpu_vram}_${driver}_${SCRIPT_RUN_TIMESTAMP}.json`

Notes:

- `SCRIPT_RUN_TIMESTAMP` is generated once per run and reused for all tests in that run.
- GPU fields are normalized/sanitized for safe filenames.

## Launch mode options (native or Proton)

The benchmark runner supports two explicit launch modes:

- `native` (default)
  - Uses native Linux executable when available.
  - If native binary is missing, falls back to Proton automatically.
- `proton`
  - Forces Windows executable launch through Proton.

Control launch mode using either CLI flags or environment variables:

- CLI flags:
  - `--native`
  - `--proton`
- Environment variables:
  - `SOTTR_LAUNCH_MODE=native|proton`
  - `SOTTR_PROTON_VERSION=<version>`
  - `SOTTR_PROTON_VERSION_DEFAULT=<version>`

Proton selection precedence:

1. `SOTTR_PROTON_VERSION`
2. `SOTTR_PROTON_VERSION_DEFAULT`
3. `PROTON_VERSION`

### Steam Compatibility setting (important)

Before switching between native and Proton runs, update the game setting in Steam:

1. Steam Library → right click **Shadow of the Tomb Raider** → **Properties** → **Compatibility**.
2. Then apply one of these modes:

- Native benchmark run (`--native`)
  - **Uncheck**: `Force the use of a specific Steam Play compatibility tool`
- Proton benchmark run (`--proton`)
  - **Check**: `Force the use of a specific Steam Play compatibility tool`
  - Select the same Proton build you use in script/env (for example `GE-Proton9-27`).

Recommended workflow when changing mode:

- Native session: unset/disable Compatibility force, then run native tests.
- Proton session: enable Compatibility force and pick Proton tool, then run Proton tests.

This avoids mixing native and Proton runtime state between sessions.

## System-specific configuration

Machine-dependent paths/settings are separated from the main script.

Config load order (later files override earlier values):

1. `system/system.<SYSTEM_NAME>.conf.sh` (optional, machine profile)
2. `SOTTR_BENCHMARK_CONFIG=/path/to/file.conf.sh` (optional runtime override)

System name selection:

- Default: short hostname from `hostname -s`
- Override for current run: `SOTTR_SYSTEM_NAME=MY_MACHINE`

Example with explicit config file:

- `SOTTR_BENCHMARK_CONFIG="/path/to/my-machine.conf.sh" games/tomb raider/benchmark/run_sottr_benchmark.sh --group native-quick`

## Reporting flow

`analyze_sottr_results.sh` reads copied benchmark result files and generates:

- `benchmark/results/sottr_benchmark_report_template.md`
- `benchmark/results/sottr_benchmark_report.md`
- `benchmark/results/sottr_benchmark_report_<timestamp>.md`

Report rows include:

- Test Name, Mode, Resolution, Quality, RT, Frame Generation
- GPU Model, GPU VRAM, Driver
- Min/Avg/Max FPS

## Test Results

Latest report files:

- [benchmark/results/sottr_benchmark_report_template.md](benchmark/results/sottr_benchmark_report_template.md)
- [benchmark/results/sottr_benchmark_report.md](benchmark/results/sottr_benchmark_report.md)

Historical snapshot reports (auto-updated by `benchmark/analyze_sottr_results.sh`):

<!-- TEST_RESULTS_START -->
- [sottr_benchmark_report_20260303_072138.md](benchmark/results/sottr_benchmark_report_20260303_072138.md)
- [sottr_benchmark_report_20260302_205207.md](benchmark/results/sottr_benchmark_report_20260302_205207.md)
- [sottr_benchmark_report_20260301_230717.md](benchmark/results/sottr_benchmark_report_20260301_230717.md)
- [sottr_benchmark_report_20260301_141758.md](benchmark/results/sottr_benchmark_report_20260301_141758.md)
- [sottr_benchmark_report_20260301_140603.md](benchmark/results/sottr_benchmark_report_20260301_140603.md)
<!-- TEST_RESULTS_END -->

## Logs and output locations

Current defaults:

- Logs directory:
  - `benchmark/logs/`
- Benchmark copied results directory:
  - `benchmark/results/`

## Profile rules

- Required naming format:
  - native launch mode: `{TEST_NAME}.preferences.xml`
  - proton launch mode: `{TEST_NAME}.preferences.user.reg`
- Strict behavior:
  - `--validate-profiles` fails if any selected test profile is missing for the active launch mode.
- Validate all profile files:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --validate-profiles`

## Usage

From repository root:

- Show help:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --help`
- List tests:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --list`
- List groups:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --groups`
- Run default test:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh`
- Run one test:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh native-1080p-high-rt-off`
- Run one or more groups:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --group native-quick`
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --group native-1080p-scaling --group native-1440p-scaling`
- Force native launch mode:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --native --group native-quick`
- Force Proton launch mode:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --proton --group proton-quick`
- Force specific Proton version for this run:
  - `SOTTR_PROTON_VERSION=GE-Proton9-27 games/tomb raider/benchmark/run_sottr_benchmark.sh --proton --group proton-quick`
- Run all tests:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --all`
- Enable GameMode wrapper:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --gamemode --group native-quick`

Analyze results:

- Analyze all tests:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh`
- Analyze a group:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh --group native-quick`
- Analyze specific tests:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh native-1080p-low-rt-off native-4k-high-rt-off`

Convert markdown reports to graphical outputs:

- Generate HTML + PNG from one report:
  - `python3 src/convert_markdown_reports.py games/tomb raider/benchmark/results/sottr_benchmark_report.md --format both`
- Generate only PNG charts split by resolution:
  - `python3 src/convert_markdown_reports.py games/tomb raider/benchmark/results/sottr_benchmark_report.md --format png --split-by-resolution`

## Notes

- Script prefers native Linux executable and falls back to Proton executable when native binary is unavailable.
- Keep shell scripts/config on LF line endings for Linux compatibility.
