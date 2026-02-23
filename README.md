# dolpa-gaming-on-linux

Benchmark automation and profile management for Cyberpunk 2077 on Linux (Steam + Proton).

## What this repo contains

- `games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh`
	- Runs predefined benchmark test sets.
	- Applies per-test `UserSettings.*.json` profiles.
	- Copies benchmark output JSON into a local `results/` folder.
- `games/cyberpunk 2077/benchmark/profiles/`
	- Contains one profile file per test name.
- `games/cyberpunk 2077/benchmark/results/`
	- Stores copied benchmark result files for each run.

## Current benchmark flow

For each test:

1. Script applies profile file:
	 - `profiles/UserSettings.{TEST_NAME}.json`
2. Launches Cyberpunk benchmark with Proton.
3. Finds latest folder matching `benchmark_*` in:
	 - `BENCHMARK_RESULTS_SOURCE_DIR`
4. Copies only `summary.json` from that latest folder into:
	 - `games/cyberpunk 2077/benchmark/results/`
5. Saved result filename format:
	 - `${GAME_ID}_result_${test_name}_${SCRIPT_RUN_TIMESTAMP}.json`

## Logs and output locations

At the end of a run, the script prints:

- Log file path (single run log)
- Logs directory path
- Benchmark results directory path

Current defaults:

- Logs directory:
	- `games/cyberpunk 2077/benchmark/logs/`
- Benchmark copied results directory:
	- `games/cyberpunk 2077/benchmark/results/`

## Profile rules

- Required naming format:
	- `UserSettings.{TEST_NAME}.json`
- Validate all profile files:
	- `"games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh" --validate-profiles`

Resolution values/indexes are expected to match test class:

- `1080p` -> `1920x1080` with `index: 11`
- `1440p` -> `2560x1440` with `index: 16`
- `4k` -> `3840x2160` with `index: 20`

## Usage

From repository root:

- Show help:
	- `"games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh" --help`
- List tests:
	- `"games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh" --list`
- Run default test:
	- `"games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh"`
- Run one test:
	- `"games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh" native-1080p-high-rt-off`
- Run a group:
	- `"games/cyberpunk 2077/benchmark/run_cp2077_benchmark.sh" --group quick`

## Notes

- Update paths at the top of `run_cp2077_benchmark.sh` if your Steam library differs.
- Script expects Cyberpunk and selected Proton build to be installed.