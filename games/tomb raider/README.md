# Shadow of the Tomb Raider (Linux/Steam Native)

Benchmark automation and profile management for Shadow of the Tomb Raider on Linux.

## What this folder contains

- `benchmark/run_sottr_benchmark.sh`
  - Runs predefined benchmark tests/groups via CLI.
  - Uses per-test native preferences snapshots: `profiles/{TEST_NAME}.preferences.xml`.
  - Copies selected preferences snapshot into live native preferences before each native run.
  - Copies benchmark outputs into local `benchmark/results/` with run + GPU metadata.
- `benchmark/analyze_sottr_results.sh`
  - Builds markdown reports from copied benchmark result files.
  - Supports filtering by test and/or group.
  - Adds GPU model / VRAM / driver columns to report rows.
- `benchmark/config/tests.conf.sh`
  - Base test catalog (non-generated test definitions).
- `benchmark/config/groups.conf.sh`
  - Base predefined groups.
- `benchmark/profiles/`
  - Contains one native preferences XML per test name.
- `benchmark/results/`
  - Stores copied benchmark result files and generated markdown reports.

## Native Linux feature differences (Feral port)

This benchmark suite is intentionally native Linux focused. For the native Linux port:

- Ray Tracing is not used.
- DLSS / FSR upscaling modes are not used.
- Frame Generation is not used.
- Resolution scaling is handled by native game settings (for example Resolution Modifier), not AI upscalers.

Because of that, this repository now keeps only native profiles and native test groups.

If you specifically want DLSS/RT/FG testing, run the Windows build via Proton and maintain a separate Proton-focused profile set.

## Available tests and how they work

Tests come directly from:

- `benchmark/config/tests.conf.sh`

Current scope is native-only and includes 12 tests:

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

- `benchmark/config/groups.conf.sh`

Key groups:

- `quick`
- `native-comparison`
- `1080p-scaling`
- `1440p-scaling`
- `4k-scaling`
- `all-native`

## Current benchmark flow

For each test:

1. Script selects test parameters from `tests.conf.sh`.
2. For native runs, script copies:
   - `benchmark/profiles/{TEST_NAME}.preferences.xml`
   - into live file:
   - `~/.local/share/feral-interactive/Shadow of the Tomb Raider/preferences`
3. Launches benchmark (native first, Proton fallback when needed).
4. Finds latest benchmark artifacts in result source location.
5. Copies normalized result artifact(s) into:
   - `benchmark/results/`
6. Saved JSON result filename format:
   - `${GAME_ID}_result_${test_name}_${gpu_model}_${gpu_vram}_${driver}_${SCRIPT_RUN_TIMESTAMP}.json`

Notes:

- `SCRIPT_RUN_TIMESTAMP` is generated once per run and reused for all tests in that run.
- GPU fields are normalized/sanitized for safe filenames.

## System-specific configuration

Machine-dependent paths/settings are separated from the main script.

Config load order (later files override earlier values):

1. `system/system.<SYSTEM_NAME>.conf.sh` (optional, machine profile)
2. `SOTTR_BENCHMARK_CONFIG=/path/to/file.conf.sh` (optional runtime override)

System name selection:

- Default: short hostname from `hostname -s`
- Override for current run: `SOTTR_SYSTEM_NAME=MY_MACHINE`

Example with explicit config file:

- `SOTTR_BENCHMARK_CONFIG="/path/to/my-machine.conf.sh" games/tomb raider/benchmark/run_sottr_benchmark.sh --group quick`

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
- [sottr_benchmark_report_20260301_141758.md](benchmark/results/sottr_benchmark_report_20260301_141758.md)
<!-- TEST_RESULTS_END -->

## Logs and output locations

Current defaults:

- Logs directory:
  - `benchmark/logs/`
- Benchmark copied results directory:
  - `benchmark/results/`

## Profile rules

- Required naming format:
  - `{TEST_NAME}.preferences.xml`
- Strict behavior:
  - `--validate-profiles` fails if any selected test profile XML is missing.
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
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --group quick`
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --group 1080p-scaling --group 1440p-scaling`
- Run all tests:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --all`
- Enable GameMode wrapper:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --gamemode --group quick`

Analyze results:

- Analyze all tests:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh`
- Analyze a group:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh --group quick`
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
