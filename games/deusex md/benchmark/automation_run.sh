#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
LOG_DIR="${SCRIPT_DIR}/logs"
RESULTS_DIR="${SCRIPT_DIR}/results"
RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
LOG_FILE="${LOG_DIR}/deusex_benchmark_${RUN_TIMESTAMP}.txt"

export GAME_ID="${GAME_ID:-337000}"
export PROTON_BIN="${PROTON_BIN:-/home/pavel/.steam/steam/compatibilitytools.d/GE-Proton10-25/proton}"
export GAME_DIR="${GAME_DIR:-/mnt/Data/Games/Steam/steamapps/common/Deus Ex Mankind Divided}"
export GAME_EXE="${GAME_EXE:-${GAME_DIR}/retail/DXMD.exe}"
export GAME_CWD="${GAME_CWD:-$(dirname "$GAME_EXE")}"
export STEAM_COMPAT_DATA_PATH="${STEAM_COMPAT_DATA_PATH:-/mnt/Data/Games/Steam/steamapps/compatdata/${GAME_ID}}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${STEAM_COMPAT_CLIENT_INSTALL_PATH:-${HOME}/.local/share/Steam}"
export PROTON_VERB="${PROTON_VERB:-waitforexitandrun}"
export STEAM_RUNTIME="${STEAM_RUNTIME:-1}"

BENCHMARK_TIMEOUT_SECONDS="${BENCHMARK_TIMEOUT_SECONDS:-900}"
BENCHMARK_KILL_AFTER_SECONDS="${BENCHMARK_KILL_AFTER_SECONDS:-60}"
TERMINATE_STALE_PROCESSES="${TERMINATE_STALE_PROCESSES:-1}"
BENCHMARK_ARGS_STRING="${BENCHMARK_ARGS:--benchmark -nolauncher}"
read -r -a BENCHMARK_ARGS <<< "$BENCHMARK_ARGS_STRING"

BENCHMARK_INI_ENABLED="${BENCHMARK_INI_ENABLED:-1}"
BENCHMARK_CONFIG_FILE="${BENCHMARK_CONFIG_FILE:-${GAME_CWD}/benchmark.ini}"
BENCHMARK_RESULTS_FILENAME="${BENCHMARK_RESULTS_FILENAME:-dxmd_benchmark_${RUN_TIMESTAMP}.csv}"
BENCHMARK_LOOP_COUNT="${BENCHMARK_LOOP_COUNT:-1}"
BENCHMARK_QUIT_WHEN_LOADED="${BENCHMARK_QUIT_WHEN_LOADED:-0}"
BENCHMARK_QUIT_AFTERWARDS="${BENCHMARK_QUIT_AFTERWARDS:-1}"
BENCHMARK_RESULTS_TO_FILE="${BENCHMARK_RESULTS_TO_FILE:-1}"
BENCHMARK_SHOW_STATISTICS="${BENCHMARK_SHOW_STATISTICS:-1}"
BENCHMARK_RESULTS_ADD_DXDIAG="${BENCHMARK_RESULTS_ADD_DXDIAG:-1}"
BENCHMARK_AUTOLOAD_SPAWNPOINT_ID="${BENCHMARK_AUTOLOAD_SPAWNPOINT_ID:-}"
BENCHMARK_SCENE="${BENCHMARK_SCENE:-assembly:/scenes/game/99_benchmark/ben_master.entity}"

BENCHMARK_INI_BACKUP_FILE=""
BENCHMARK_INI_CREATED="0"

log() {
	local level="$1"
	shift
	local message="$*"
	echo "[$(date '+%Y-%m-%d %H:%M:%S')] [$level] $message" | tee -a "$LOG_FILE"
}

require_cmd() {
	local cmd="$1"
	if ! command -v "$cmd" >/dev/null 2>&1; then
		echo "Required command not found: $cmd" >&2
		exit 1
	fi
}

normalize_seconds_var() {
	local var_name="$1"
	local raw_value="${!var_name:-}"
	local normalized_value="${raw_value%s}"

	if [[ -z "$normalized_value" || ! "$normalized_value" =~ ^[0-9]+$ ]]; then
		log ERROR "$var_name must be an integer number of seconds (or end with 's'), got: '$raw_value'"
		exit 1
	fi

	printf -v "$var_name" '%s' "$normalized_value"
}

normalize_zero_one_var() {
	local var_name="$1"
	local raw_value="${!var_name:-}"

	if [[ "$raw_value" != "0" && "$raw_value" != "1" ]]; then
		log ERROR "$var_name must be 0 or 1, got: '$raw_value'"
		exit 1
	fi
}

normalize_positive_int_var() {
	local var_name="$1"
	local raw_value="${!var_name:-}"

	if [[ -z "$raw_value" || ! "$raw_value" =~ ^[0-9]+$ || "$raw_value" -le 0 ]]; then
		log ERROR "$var_name must be a positive integer, got: '$raw_value'"
		exit 1
	fi
}

kill_stale_processes() {
	pkill -f "DXMD.exe|wineserver|proton|DXMD" >/dev/null 2>&1 || true
}

kill_stale_processes_if_enabled() {
	if [[ "$TERMINATE_STALE_PROCESSES" == "1" ]]; then
		kill_stale_processes
	fi
}

write_benchmark_ini_block() {
	local section_name="$1"

	if [[ -n "$section_name" ]]; then
		echo "[${section_name}]"
	fi

	echo "Scene=${BENCHMARK_SCENE}"
	echo "QuitWhenLoaded=${BENCHMARK_QUIT_WHEN_LOADED}"
	echo "QuitAfterwards=${BENCHMARK_QUIT_AFTERWARDS}"
	echo "ResultsToFile=${BENCHMARK_RESULTS_TO_FILE}"
	echo "ShowStatistics=${BENCHMARK_SHOW_STATISTICS}"
	echo "ResultsAddDXDIAG=${BENCHMARK_RESULTS_ADD_DXDIAG}"
	echo "ResultsFileName=${BENCHMARK_RESULTS_FILENAME}"
	echo "LoopCount=${BENCHMARK_LOOP_COUNT}"
	if [[ -n "$BENCHMARK_AUTOLOAD_SPAWNPOINT_ID" ]]; then
		echo "AutoLoadSpawnPointID=${BENCHMARK_AUTOLOAD_SPAWNPOINT_ID}"
	fi
}

prepare_benchmark_ini() {
	if [[ "$BENCHMARK_INI_ENABLED" != "1" ]]; then
		log INFO "BENCHMARK_INI_ENABLED=0, skipping benchmark.ini generation"
		return 0
	fi

	if [[ "$BENCHMARK_CONFIG_FILE" != /* ]]; then
		BENCHMARK_CONFIG_FILE="${GAME_DIR}/${BENCHMARK_CONFIG_FILE}"
	fi

	mkdir -p "$(dirname "$BENCHMARK_CONFIG_FILE")"

	if [[ -f "$BENCHMARK_CONFIG_FILE" ]]; then
		BENCHMARK_INI_BACKUP_FILE="${BENCHMARK_CONFIG_FILE}.bak.${RUN_TIMESTAMP}"
		cp "$BENCHMARK_CONFIG_FILE" "$BENCHMARK_INI_BACKUP_FILE"
		log INFO "Backed up existing benchmark.ini to $BENCHMARK_INI_BACKUP_FILE"
	fi

	{
		write_benchmark_ini_block ""
		echo
		write_benchmark_ini_block "benchmark"
		echo
		write_benchmark_ini_block "main"
	} > "$BENCHMARK_CONFIG_FILE"

	BENCHMARK_INI_CREATED="1"
	log INFO "Generated benchmark.ini: $BENCHMARK_CONFIG_FILE"
}

restore_benchmark_ini() {
	if [[ "$BENCHMARK_INI_CREATED" != "1" ]]; then
		return 0
	fi

	if [[ -n "$BENCHMARK_INI_BACKUP_FILE" && -f "$BENCHMARK_INI_BACKUP_FILE" ]]; then
		mv "$BENCHMARK_INI_BACKUP_FILE" "$BENCHMARK_CONFIG_FILE"
		log INFO "Restored original benchmark.ini"
	else
		rm -f "$BENCHMARK_CONFIG_FILE"
		log INFO "Removed generated benchmark.ini"
	fi
}

collect_benchmark_results() {
	if [[ "$BENCHMARK_RESULTS_TO_FILE" != "1" ]]; then
		return 0
	fi

	mkdir -p "$RESULTS_DIR"

	local docs_dir="${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/Documents/Deus Ex -  Mankind Divided"
	local -a candidates=(
		"${GAME_DIR}/${BENCHMARK_RESULTS_FILENAME}"
		"${GAME_CWD}/${BENCHMARK_RESULTS_FILENAME}"
		"$(dirname "$GAME_EXE")/${BENCHMARK_RESULTS_FILENAME}"
		"${docs_dir}/${BENCHMARK_RESULTS_FILENAME}"
	)

	local candidate=""
	for candidate in "${candidates[@]}"; do
		if [[ -f "$candidate" ]]; then
			local destination="${RESULTS_DIR}/${RUN_TIMESTAMP}_${BENCHMARK_RESULTS_FILENAME}"
			cp "$candidate" "$destination"
			log INFO "Copied benchmark result file: $destination"
			return 0
		fi
	done

	log WARNING "Benchmark result file not found (${BENCHMARK_RESULTS_FILENAME}) in expected locations"
}

cleanup() {
	restore_benchmark_ini

	env \
		"STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_COMPAT_CLIENT_INSTALL_PATH" \
		"STEAM_COMPAT_DATA_PATH=$STEAM_COMPAT_DATA_PATH" \
		"$PROTON_BIN" run wineserver -k >>"$LOG_FILE" 2>&1 || true

	kill_stale_processes_if_enabled
}

run_benchmark() {
	local -a launch_cmd=(
		timeout --foreground --signal=TERM --kill-after="${BENCHMARK_KILL_AFTER_SECONDS}s" "${BENCHMARK_TIMEOUT_SECONDS}s"
		env
		"PROTON_LOG=1"
		"SteamAppId=$GAME_ID"
		"SteamGameId=$GAME_ID"
		"PROTON_VERB=$PROTON_VERB"
		"STEAM_RUNTIME=$STEAM_RUNTIME"
		"VKD3D_FEATURE_LEVEL=12_2"
		"PROTON_HIDE_NVIDIA_GPU=0"
		"PROTON_ENABLE_NVAPI=1"
		"VKD3D_CONFIG=dxr12"
		"DXVK_ASYNC=1"
		"$PROTON_BIN" run "$GAME_EXE"
		"${BENCHMARK_ARGS[@]}"
	)

	local launch_cmd_pretty
	printf -v launch_cmd_pretty '%q ' "${launch_cmd[@]}"
	log INFO "Launch command: cd $(printf '%q' "$GAME_CWD") && ${launch_cmd_pretty% }"

	(
		cd "$GAME_CWD" || exit 1
		"${launch_cmd[@]}"
	) >>"$LOG_FILE" 2>&1
}

validate_runtime_configuration() {
	require_cmd timeout

	if [[ ! -x "$PROTON_BIN" ]]; then
		log ERROR "Proton not found or not executable: $PROTON_BIN"
		exit 1
	fi

	if [[ ! -d "$GAME_DIR" ]]; then
		log ERROR "Game directory not found: $GAME_DIR"
		exit 1
	fi

	if [[ ! -d "$GAME_CWD" ]]; then
		log ERROR "Game working directory not found: $GAME_CWD"
		exit 1
	fi

	if [[ ! -f "$GAME_EXE" ]]; then
		log ERROR "Game executable not found: $GAME_EXE"
		exit 1
	fi

	normalize_seconds_var BENCHMARK_TIMEOUT_SECONDS
	normalize_seconds_var BENCHMARK_KILL_AFTER_SECONDS
	normalize_zero_one_var TERMINATE_STALE_PROCESSES
	normalize_zero_one_var BENCHMARK_INI_ENABLED
	normalize_zero_one_var BENCHMARK_QUIT_WHEN_LOADED
	normalize_zero_one_var BENCHMARK_QUIT_AFTERWARDS
	normalize_zero_one_var BENCHMARK_RESULTS_TO_FILE
	normalize_zero_one_var BENCHMARK_SHOW_STATISTICS
	normalize_zero_one_var BENCHMARK_RESULTS_ADD_DXDIAG
	normalize_positive_int_var BENCHMARK_LOOP_COUNT
}

mkdir -p "$LOG_DIR" "$RESULTS_DIR"

validate_runtime_configuration

trap cleanup EXIT INT TERM

log INFO "Starting Deus Ex Mankind Divided benchmark run"
log INFO "Log file: $LOG_FILE"
log INFO "Benchmark args: ${BENCHMARK_ARGS[*]}"
log INFO "CLI-only mode: screen/menu automation is disabled by design"

if [[ -n "${AUTO_START_BENCHMARK_FROM_MENU:-}" ]]; then
	log INFO "AUTO_START_BENCHMARK_FROM_MENU is ignored in CLI-only mode"
fi

prepare_benchmark_ini

if [[ "$TERMINATE_STALE_PROCESSES" == "1" ]]; then
	log INFO "Terminating stale DXMD/Proton processes before launch"
	kill_stale_processes_if_enabled
	sleep 1
fi

exit_code=0
if run_benchmark; then
	log INFO "Benchmark process finished"
else
	exit_code=$?
	if [[ $exit_code -eq 124 || $exit_code -eq 137 ]]; then
		log ERROR "Benchmark timed out after ${BENCHMARK_TIMEOUT_SECONDS}s"
	else
		log ERROR "Benchmark failed (exit code: $exit_code)"
	fi
fi

collect_benchmark_results

if [[ $exit_code -eq 0 ]]; then
	log INFO "Automation run completed successfully"
fi

exit "$exit_code"
