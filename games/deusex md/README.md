# Deus Ex: Mankind Divided (Linux/Steam/Proton)

Benchmark automation and profile management for Deus Ex: Mankind Divided on Linux (Steam + Proton).

## What this folder contains

- `benchmark/run_deusex-md_benchmark.sh`
    - Runs predefined benchmark tests/groups via CLI.
    - Applies strict per-test `{TEST_NAME}.user.reg` profiles to Proton prefix.
    - Copies benchmark output artifacts (CSV preferred, JSON fallback) into local `results/` with run + GPU metadata.
- `benchmark/analyze_deus-ex_results.sh`
    - Builds markdown reports from copied benchmark JSON/CSV files.
    - Supports filtering by test and/or group.
    - Adds GPU model / VRAM / driver columns to report rows.
- `benchmark/config/tests.conf.sh`
    - Base test catalog.
- `benchmark/config/groups.conf.sh`
    - Base predefined groups.
- `benchmark/profiles/`
    - Contains one `.user.reg` profile file per test name.
- `benchmark/results/`
    - Stores copied benchmark result files and generated markdown reports.
- `benchmark/run_sanity_checks.sh`
    - Quick syntax/list/profile checks and optional smoke run.

## Available tests and how they work

Tests are built in two layers:

1. Base tests from:
    - `benchmark/config/tests.conf.sh`
2. Runtime filtering and augmentation:
    - Runner keeps only tests with `proton-` prefix.
    - For every base test `X`, if profile exists, script can auto-add:
        - `X-fg`

This means `--list` shows:

- All Proton tests from `tests.conf.sh`
- Plus discovered `-fg` variants if corresponding `.user.reg` profiles exist

### Test naming convention

`proton-{1080p|1440p|4k}-{low|medium|high|very-high|ultra}[-fg]`

Examples:

- `proton-1080p-low`
- `proton-1080p-high`
- `proton-1440p-ultra`
- `proton-4k-very-high`

### Test groups

Groups are built from config and runtime generation:

1. Base groups from:
    - `benchmark/config/groups.conf.sh`
2. Runtime behavior:
    - Groups are filtered to Proton tests only.
    - Dynamic full-resolution groups are generated from available tests:
        - `all-1080p-tests`
        - `all-1440p-tests`
        - `all-4k-tests`

So `--groups` reflects active Proton test coverage.

## Current benchmark flow

For each test:

1. Script applies profile file:
    - `profiles/{TEST_NAME}.user.reg`
2. Optionally generates benchmark config file (`benchmark.ini`) in game settings location.
3. Launches Deus Ex benchmark via Steam + Proton.
4. Collects benchmark artifacts from known source paths:
    - First tries configured CSV filename (`BENCHMARK_RESULTS_FILENAME`) if set.
    - Then newest CSV in source directories.
    - Falls back to newest `summary.json` in `benchmark_*` directories.
5. Saves result file into `benchmark/results/`:
    - CSV copy:
        - `${GAME_ID}_result_${test_name}_${gpu_model}_${gpu_vram}_${driver}_${SCRIPT_RUN_TIMESTAMP}_${original_csv_name}.csv`
    - JSON copy:
        - `${GAME_ID}_result_${test_name}_${gpu_model}_${gpu_vram}_${driver}_${SCRIPT_RUN_TIMESTAMP}.json`

Notes:

- `SCRIPT_RUN_TIMESTAMP` is generated once per run and reused for all tests in that run.
- GPU fields are normalized/sanitized for safe filenames.
- Native mode is intentionally disabled; Proton is the only supported launch mode.

## Current development status

Current status (as observed): benchmark automation is functional up to execution completion. The benchmark starts correctly from `run_deusex-md_benchmark.sh`, test-specific user settings (`.user.reg`) are applied, the game runs the benchmark, and it exits cleanly at the end. The remaining blocker is result persistence: benchmark results are currently not being saved to output files, so no usable JSON/CSV artifacts are available for reporting.

## System-specific configuration

Machine-dependent paths/settings are separated from the main script.

Config load order (later files override earlier values):

1. `system/system.<SYSTEM_NAME>.conf.sh` (optional machine profile)
2. `DEUSEX_MD_BENCHMARK_CONFIG=/path/to/file.conf.sh` (optional runtime override)

Quick setup for a new machine:

1. Create a machine file (example for host `AORUS`):
    - `cp "system/system.aorus.conf.sh" "system/system.my_machine.conf.sh"`
2. Edit `system.my_machine.conf.sh` with your local Steam/library/Proton paths.
3. Run benchmark normally.

System name selection:

- Default: normalized short hostname (`hostname -s`)
- Override for current run: `DEUSEX_MD_SYSTEM_NAME=my_machine`

Example with explicit config file:

- `DEUSEX_MD_BENCHMARK_CONFIG="/path/to/my-lab-machine.conf.sh" "games/deusex md/benchmark/run_deusex-md_benchmark.sh" --group all-4k-tests`

## Reporting flow

`analyze_deus-ex_results.sh` reads benchmark JSON/CSV files and generates:

- `benchmark/results/deus_ex_md_benchmark_report_template.md`
- `benchmark/results/deus_ex_md_benchmark_report.md`
- `benchmark/results/deus_ex_md_benchmark_report_<timestamp>.md`

Report rows include:

- Test Name, Mode, Resolution, Quality, Ray Tracing, Frame Generation
- GPU Model, GPU VRAM, Driver
- Min/Avg/Max FPS

Analyzer supports both filename styles:

- GPU-aware filenames (preferred)
- Legacy filenames without GPU fields (reported as `unknown-*`)

## Test Results

Standard testrun:
`
./run_deusex-md_benchmark.sh --group all-1080p-tests --group all-1440p-tests --group all-4k-tests
`

Latest report files:

- [benchmark/results/deus_ex_md_benchmark_report_template.md](benchmark/results/deus_ex_md_benchmark_report_template.md)
- [benchmark/results/deus_ex_md_benchmark_report.md](benchmark/results/deus_ex_md_benchmark_report.md)

Historical snapshot reports (auto-updated by `benchmark/analyze_deus-ex_results.sh`):

<!-- TEST_RESULTS_START -->
- _No reports added yet._
<!-- TEST_RESULTS_END -->

## Logs and output locations

At the end of a run, the script prints:

- Log file path (single run log)
- Logs directory path
- Benchmark results directory path

Current defaults:

- Logs directory:
    - `benchmark/logs/`
- Benchmark copied results directory:
    - `benchmark/results/`

## Profile rules

- Required naming format:
    - `{TEST_NAME}.user.reg`
- Strict behavior:
    - Benchmark run fails fast if the exact profile file for selected test is missing.
- Validate all profile files:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --validate-profiles`

Resolution values are expected to match test class:

- `1080p` -> `1920x1080`
- `1440p` -> `2560x1440`
- `4k` -> `3840x2160`

## Usage

From repository root:

- Show help:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --help`
- List tests:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --list`
- List groups:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --groups`
- Run default test:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh"`
- Run one test:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" proton-1080p-high`
- Run one or more groups:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --group all-4k-tests`
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --group all-1080p-tests --group all-1440p-tests`
- Run all tests:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --all`
- Enable GameMode launch wrapper:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --gamemode --group all-4k-tests`
- Validate profile files:
    - `"games/deusex md/benchmark/run_deusex-md_benchmark.sh" --validate-profiles`

Analyze results:

- Analyze all tests:
    - `"games/deusex md/benchmark/analyze_deus-ex_results.sh"`
- Analyze a group:
    - `"games/deusex md/benchmark/analyze_deus-ex_results.sh" --group all-4k-tests`
- Analyze specific tests:
    - `"games/deusex md/benchmark/analyze_deus-ex_results.sh" proton-1080p-low proton-4k-ultra`

Sanity checks:

- Basic checks:
    - `"games/deusex md/benchmark/run_sanity_checks.sh"`
- Include smoke test benchmark:
    - `"games/deusex md/benchmark/run_sanity_checks.sh" --smoke`
- Run analyzer after checks:
    - `"games/deusex md/benchmark/run_sanity_checks.sh" --analyze`

Convert markdown reports to graphical outputs:

- Generate HTML + PNG from one report:
    - `python3 src/convert_markdown_reports.py "games/deusex md/benchmark/results/deus_ex_md_benchmark_report.md" --format both`
- Generate only PNG charts split by resolution:
    - `python3 src/convert_markdown_reports.py "games/deusex md/benchmark/results/deus_ex_md_benchmark_report.md" --format png --split-by-resolution`
- Process multiple report files at once:
    - `python3 src/convert_markdown_reports.py "games/deusex md/benchmark/results/deus_ex_md_benchmark_report.md" "games/deusex md/benchmark/results/deus_ex_md_benchmark_report_20260305_120000.md" --format html`

## Notes

- Update machine config under `system/` if your Steam library paths differ.
- Script expects Deus Ex: Mankind Divided and selected Proton build to be installed.
- Native mode is explicitly unsupported by this runner.
- Keep shell scripts/config on LF line endings for Linux compatibility.
