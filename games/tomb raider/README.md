# Shadow of the Tomb Raider (Linux/Steam Native + Proton Fallback)

Benchmark automation and profile management for Shadow of the Tomb Raider on Linux.

## What this folder contains

- `benchmark/run_sottr_benchmark.sh`
  - Runs predefined benchmark tests/groups via CLI.
  - Uses per-test native preferences snapshots: `profiles/{TEST_NAME}.preferences.xml`.
  - Copies selected preferences snapshot into live native preferences before each native run.
  - Copies benchmark output JSON into local `benchmark/results/` with run + GPU metadata.
- `benchmark/analyze_sottr_results.sh`
  - Builds markdown reports from copied benchmark JSON files.
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

## Available tests and how they work

Tests are built in two layers:

1. Base tests from:
   - `benchmark/config/tests.conf.sh`
2. Auto-generated FG variants at runtime:
   - For every base test `X`, if `profiles/X-fg-*.preferences.xml` exists, script auto-adds:
     - `X-fg-dlss`
     - `X-fg-frs31`
     - `X-fg` (legacy compatibility)

This means `--list` shows:

- All base tests from `tests.conf.sh`
- Plus all discovered FG variants that have matching `.preferences.xml` files

### Test naming convention

`{mode}-{resolution}-{quality}-rt-{off|on|psycho}[-fg-dlss|-fg-frs31|-fg]`

Examples:

- `native-1080p-high-rt-off`
- `dlss-quality-1440p-high-rt-on`
- `fsr2-performance-4k-low-rt-off`
- `fsr3-quality-4k-high-rt-off-fg`

### Test groups

Groups are also built in two layers:

1. Base groups from:
   - `benchmark/config/groups.conf.sh`
2. Runtime augmentation:
   - Existing groups are expanded with matching `-fg` variants when available.
   - Resolution quick groups are auto-generated from `4k-quick-*` groups:
     - `1080p-quick-low|medium|high|ultra`
     - `1440p-quick-low|medium|high|ultra`

So `--groups` always reflects current test coverage.

## Current benchmark flow

For each test:

1. Script selects test parameters from `tests.conf.sh`.
2. For native runs, script copies:
   - `benchmark/profiles/{TEST_NAME}.preferences.xml`
   - into live file:
   - `~/.local/share/feral-interactive/Shadow of the Tomb Raider/preferences`
3. Launches benchmark (native first, Proton fallback when needed).
4. Finds latest folder matching `benchmark_*` in result source location.
5. Copies `summary.json` into:
   - `benchmark/results/`
6. Saved result filename format:
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

- `SOTTR_BENCHMARK_CONFIG="/path/to/my-machine.conf.sh" games/tomb raider/benchmark/run_sottr_benchmark.sh --group quick-4k`

## Reporting flow

`analyze_sottr_results.sh` reads benchmark JSON files and generates:

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
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --group quick-4k`
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --group 1080p-quick-high --group 1440p-quick-high`
- Run all tests:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --all`
- Enable GameMode wrapper:
  - `games/tomb raider/benchmark/run_sottr_benchmark.sh --gamemode --group quick-4k`

Analyze results:

- Analyze all tests:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh`
- Analyze a group:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh --group quick-4k`
- Analyze specific tests:
  - `games/tomb raider/benchmark/analyze_sottr_results.sh native-1080p-low-rt-off dlss-quality-4k-high-rt-on`

Convert markdown reports to graphical outputs:

- Generate HTML + PNG from one report:
  - `python3 src/convert_markdown_reports.py games/tomb raider/benchmark/results/sottr_benchmark_report.md --format both`
- Generate only PNG charts split by resolution:
  - `python3 src/convert_markdown_reports.py games/tomb raider/benchmark/results/sottr_benchmark_report.md --format png --split-by-resolution`

## Notes

- Script prefers native Linux executable and falls back to Proton executable when native binary is unavailable.
- Keep shell scripts/config on LF line endings for Linux compatibility.
