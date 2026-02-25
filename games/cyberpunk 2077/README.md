# Cyberpunk 2077 (Linux/Steam/Proton)

Benchmark automation and profile management for Cyberpunk 2077 on Linux (Steam + Proton).

## What this folder contains

- `benchmark/run_cp2077_benchmark.sh`
	- Runs predefined benchmark tests/groups via CLI.
	- Applies strict per-test `UserSettings.{TEST_NAME}.json` profiles.
	- Copies benchmark output JSON into local `results/` with run + GPU metadata.
- `benchmark/analyze_cp2077_results.sh`
	- Builds markdown reports from copied benchmark JSON files.
	- Supports filtering by test and/or group.
	- Adds GPU model / VRAM / driver columns to report rows.
- `benchmark/config/tests.conf.sh`
	- Base test catalog (non-generated test definitions).
- `benchmark/config/groups.conf.sh`
	- Base predefined groups.
- `benchmark/profiles/`
	- Contains one profile file per test name.
- `benchmark/results/`
	- Stores copied benchmark result files and generated markdown reports.

## Available tests and how they work

Tests are built in two layers:

1. Base tests from:
	- `benchmark/config/tests.conf.sh`
2. Auto-generated FG variants at runtime:
	- For every base test `X`, if profile exists, script auto-adds:
		- `X-fg-dlss`
		- `X-fg-frs31`
		- `X-fg` (legacy compatibility)

This means `--list` shows:

- All base tests from `tests.conf.sh`
- Plus all discovered FG variants that have matching profile files

### Test naming convention

`{mode}-{resolution}-{quality}-rt-{off|on|psycho}[-fg-dlss|-fg-frs31|-fg]`

Examples:

- `native-1080p-high-rt-off`
- `dlss-quality-1440p-high-rt-on`
- `fsr2-performance-4k-low-rt-off`
- `native-4k-low-rt-off-fg-dlss`
- `native-4k-low-rt-off-fg-frs31`

### Test groups

Groups are also built in two layers:

1. Base groups from:
	- `benchmark/config/groups.conf.sh`
2. Runtime augmentation:
	- Existing groups are expanded with matching `-fg` variants when available.
	- Resolution quick groups are auto-generated from `4k-quick-*` groups:
		- `1080p-quick-low|medium|high|ultra`
		- `1440p-quick-low|medium|high|ultra`

So `--groups` always reflects current test coverage, including newly added profiles.

## Current benchmark flow

For each test:

1. Script applies profile file:
	- `profiles/UserSettings.{TEST_NAME}.json`
2. Launches Cyberpunk benchmark with Proton.
3. Finds latest folder matching `benchmark_*` in:
	- `BENCHMARK_RESULTS_SOURCE_DIR`
4. Copies only `summary.json` from that latest folder into:
	- `benchmark/results/`
5. Saved result filename format:
	- `${GAME_ID}_result_${test_name}_${gpu_model}_${gpu_vram}_${driver}_${SCRIPT_RUN_TIMESTAMP}.json`

Notes:

- `SCRIPT_RUN_TIMESTAMP` is generated once per run and reused for all tests in that run.
- GPU fields are normalized/sanitized for safe filenames.

## Reporting flow

`analyze_cp2077_results.sh` reads benchmark JSON files and generates:

- `benchmark/results/cp2077_benchmark_report_template.md`
- `benchmark/results/cp2077_benchmark_report.md`
- `benchmark/results/cp2077_benchmark_report_<timestamp>.md`

Report rows include:

- Test Name, Mode, Resolution, Quality, RT, Frame Generation
- GPU Model, GPU VRAM, Driver
- Min/Avg/Max FPS

Analyzer supports both filename styles:

- New GPU-aware filenames (preferred)
- Legacy filenames without GPU fields (reported as `unknown-*`)

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
	- `UserSettings.{TEST_NAME}.json`
- Strict behavior:
	- Benchmark run fails fast if the exact profile file for selected test is missing.
- Validate all profile files:
	- `benchmark/run_cp2077_benchmark.sh --validate-profiles`

Resolution values/indexes are expected to match test class:

- `1080p` -> `1920x1080` with `index: 11`
- `1440p` -> `2560x1440` with `index: 16`
- `4k` -> `3840x2160` with `index: 20`

## Usage

From repository root:

- Show help:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --help`
- List tests:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --list`
- List groups:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --groups`
- Run default test:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh`
- Run one test:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh native-1080p-high-rt-off`
- Run one or more groups:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --group quick-4k`
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --group 1080p-quick-high --group 1440p-quick-high`
- Run all tests:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --all`
- Enable GameMode launch wrapper:
	- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh --gamemode --group quick-4k`

Analyze results:

- Analyze all tests:
	- `games/cyberpunk 2077/benchmark/analyze_cp2077_results.sh`
- Analyze a group:
	- `games/cyberpunk 2077/benchmark/analyze_cp2077_results.sh --group quick-4k`
- Analyze specific tests:
	- `games/cyberpunk 2077/benchmark/analyze_cp2077_results.sh native-1080p-low-rt-off dlss-quality-4k-high-rt-on`

## Notes

- Update paths at the top of `benchmark/run_cp2077_benchmark.sh` if your Steam library differs.
- Script expects Cyberpunk and selected Proton build to be installed.
- Keep shell scripts/config on LF line endings for Linux compatibility.
