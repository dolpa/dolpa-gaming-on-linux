#!/usr/bin/env bash
#=====================================================================
#  run_ac-valhalla_benchmark.sh – Assassin’s Creed Valhalla Upscaling Benchmark
#=====================================================================
#  This script is a copy‑and‑paste of the Cyberpunk 2077 benchmark
#  runner, renamed and tweaked for AC Valhalla.  All “cy2077” symbols
#  have been replaced by “ac‑valhalla”, the default paths now point to
#  the Valhalla folders, and the shared logging library is used.
#=====================================================================

# --------------------------------------------------------------------
#  System‑wide configuration (built‑in defaults – may be overridden)
# --------------------------------------------------------------------
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"      # directory where this script lives (used for locating configs, logs, …)
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"        # root of the project (used for locating the shared bash‑utils library, and as a base for system‑specific configs)
SYSTEM_CONFIG_DIR="${PROJECT_ROOT_DIR}/system"                  # directory where system‑specific configuration files are expected to live (e.g. system.my‑pc.conf.sh)
SYSTEM_NAME_DEFAULT=""                                          # default system name (can be overridden by the local config); if empty, it will be derived from the hostname
GAME_SHORT_NAME="ac-valhalla"                                   # short name for the game (used for folder names, logs, …); should be lowercase and contain only letters, numbers and dashes/underscores


# --------------------------------------------------------------------
#  Local system configuration (per‑machine)
# --------------------------------------------------------------------
SYSTEM_NAME="$(hostname -s 2>/dev/null || echo "default")"  # use the short hostname as the default system name; fallback to "default" if hostname is not available
SYSTEM_NAME="${SYSTEM_NAME,,}"                      # convert to lowercase
SYSTEM_NAME="$(printf '%s' "$SYSTEM_NAME" | sed -E 's/pavel//g; s/dolpa//g; s/[-_.]+/-/g; s/^-+|-+$//g')"   # remove common personal name parts and replace separators with dashes; also trim leading/trailing dashes
if [[ -z "$SYSTEM_NAME_DEFAULT" ]]; then
    SYSTEM_NAME_DEFAULT="default"   # if the resulting name is empty after cleanup, use "default"
fi
SYSTEM_NAME="${SYSTEM_NAME:-$SYSTEM_NAME_DEFAULT}"  # use the default if SYSTEM_NAME is empty
SYSTEM_NAME="${SYSTEM_NAME// /_}"                   # replace any remaining spaces with underscores (just in case)

# Resolve a system‑specific configuration file (e.g. system.my‑pc.conf.sh)
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${HOSTNAME}.conf.sh"
GAME_BENCHMARK_CONFIG_DEFAULT="${SCRIPT_DIR}/config/game.${GAME_SHORT_NAME}.conf.sh"  # default game‑specific config (can be overridden by the environment variable GAME_BENCHMARK_CONFIG)
SYSTEM_CONFIG_OVERRIDE_FILE="${GAME_BENCHMARK_CONFIG:-}"   # <- env‑var

# --------------------------------------------------------------------
#  Default values (can be overridden by the config files below)
# --------------------------------------------------------------------
PROTON_VERSION_DEFAULT="GE-Proton10-32"  # default Proton version to use for the script (can be overridden by the system default config or the environment variable GAME_PROTON_VERSION)

# Game/Steam identifiers
GAME_ID=2208920                             # Steam AppID for Assassin’s Creed Valhalla
GAME_NAME="Assassin’s Creed Valhalla"       # Human‑friendly game name (used for logging, folder names, …)
STEAM_PATH="${HOME}/.local/share/Steam"     # Base path to Steam (used for Proton, compatdata, …)
STEAM_ROOT="${HOME}/.steam/root"            # Steam root path
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam" # Custom Steam library path (where the game is installed) – override in config if needed

# Behaviour toggles
ENABLE_MANGOHUD=0                           # Enable MangoHud overlay for all tests (if installed and detected by the shared library)
ENABLE_GAMEMODERUN=0                        # Run the game under gamemode (if installed and detected by the shared library)
BENCHMARK_TIMEOUT_MINUTES=15                # Default timeout for each benchmark test (in minutes) – can be overridden by --timeout-minutes; if BENCHMARK_TIMEOUT_SECONDS is set, it takes precedence over this value.
BENCHMARK_TIMEOUT_SECONDS=""                # if empty, it will be computed from BENCHMARK_TIMEOUT_MINUTES
BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS=30     # If a test times out, wait this many seconds before force‑killing it (to allow for graceful shutdown)

# Directories that can be overridden later
USER_SETTINGS_FOLDER=""
BENCHMARK_RESULTS_SOURCE_DIR=""
BENCHMARK_RESULTS_OUTPUT_DIR="${SCRIPT_DIR}/results"



# --------------------------------------------------------------------
#  Check for the shared bash‑utils library (must be done before loading configs, as they may rely on it for logging, GPU detection, etc.)
# --------------------------------------------------------------------
BASH_UTILS_LOADER="${SCRIPT_DIR}/../../../dolpa-bash-utils/bash-utils.sh"
if [[ ! -f "$BASH_UTILS_LOADER" ]]; then
    echo "Error: dolpa-bash-utils loader not found: $BASH_UTILS_LOADER" >&2
    exit 1
fi

# --------------------------------------------------------------------
#  Load system configuration files (they may overwrite the defaults)
# --------------------------------------------------------------------
# 1) Local system config (per‑machine)
if [[ -f "${SYSTEM_CONFIG_LOCAL_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${SYSTEM_CONFIG_LOCAL_FILE}"
else
    log_to_file "warning" "No local system config found at ${SYSTEM_CONFIG_LOCAL_FILE} – using defaults"
fi

# 2) Game config (defaults for the specific game, shared across all machines – expected to live in the same folder as this script, but can be overridden by the environment variable GAME_BENCHMARK_CONFIG)
if [[ -n "${GAME_BENCHMARK_CONFIG_DEFAULT}" && -f "${GAME_BENCHMARK_CONFIG_DEFAULT}" ]]; then
    # shellcheck source=/dev/null
    source "${GAME_BENCHMARK_CONFIG_DEFAULT}"
fi

# 3) Override config supplied via an environment variable
if [[ -n "${SYSTEM_CONFIG_OVERRIDE_FILE}" && -f "${SYSTEM_CONFIG_OVERRIDE_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${SYSTEM_CONFIG_OVERRIDE_FILE}"
fi

# --------------------------------------------------------------------
#  Derived / helper variables (must be evaluated **after** the configs)
# --------------------------------------------------------------------
PROTON_VERSION="${GAME_PROTON_VERSION:-${PROTON_VERSION:-${PROTON_VERSION_DEFAULT}}}"

# Compute timeout in seconds if not explicitly set
if [[ -z "${BENCHMARK_TIMEOUT_SECONDS:-}" ]]; then
    BENCHMARK_TIMEOUT_SECONDS=$(( BENCHMARK_TIMEOUT_MINUTES * 60 ))
fi

# Default user‑settings folder (Steam‑Play “compatdata” path)
if [[ -z "${USER_SETTINGS_FOLDER:-}" ]]; then
    USER_SETTINGS_FOLDER="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/AppData/Local/Ubisoft/Assassin's Creed Valhalla"
fi

# Default benchmark results source directory (where the game writes its CSVs)
if [[ -z "${BENCHMARK_RESULTS_SOURCE_DIR:-}" ]]; then
    BENCHMARK_RESULTS_SOURCE_DIR="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Ubisoft/Assassin's Creed Valhalla/benchmarkResults/"
fi

# --------------------------------------------------------------------
#  Load the shared bash‑utils library (provides logging helpers, GPU detection, …)
# --------------------------------------------------------------------
BASH_UTILS_LOADER="${SCRIPT_DIR}/../../../dolpa-bash-utils/bash-utils.sh"
if [[ ! -f "${BASH_UTILS_LOADER}" ]]; then
    echo "Error: dolpa‑bash‑utils loader not found: ${BASH_UTILS_LOADER}" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "${BASH_UTILS_LOADER}"

# --------------------------------------------------------------------
#  Load the benchmark‑specific test definitions
# --------------------------------------------------------------------
#   tests.config.sh   – associative array  TESTS[<name>]=<command>
#   groups.config.sh  – associative array  TEST_GROUPS[<group>]="<test1> <test2> ..."
# --------------------------------------------------------------------
# (Both files are expected to live in the same directory as this script)
source "${SCRIPT_DIR}/tests.config.sh"
source "${SCRIPT_DIR}/groups.config.sh"

# --------------------------------------------------------------------
#  Helper functions (you can extend them later)
# --------------------------------------------------------------------
show_help() {
    cat <<EOF
Assassin’s Creed Valhalla Upscaling Benchmark runner

Usage:  $(basename "$0") [options] [test …]

Options:
  -h, --help               Show this help
  --list                   List all available tests
  --groups                 List all defined groups
  --validate-profiles      Validate that all benchmark profiles exist
  --gamemode               Run the game under gamemode
  --group <name>           Run every test from the named group
  --timeout-minutes <N>    Set per‑test timeout (default: ${BENCHMARK_TIMEOUT_MINUTES} min)
  --all                    Run **all** tests defined in tests.config.sh
EOF
}

list_tests() {
    echo "Available tests:"
    for t in "${!TESTS[@]}"; do
        echo "  $t"
    done
}

list_groups() {
    echo "Available groups:"
    for g in "${!TEST_GROUPS[@]}"; do
        echo "  $g"
    done
}

validate_profiles() {
    local missing=0
    for profile in "${TESTS[@]}"; do
        # the command stored in TESTS[<name>] is expected to be a CSV‑profile path;
        # you may adapt the check to your own format.
        if [[ ! -f "${profile}" ]]; then
            log_error "Missing benchmark profile: ${profile}"
            ((missing++))
        fi
    done
    (( missing )) && return 1 || return 0
}

# --------------------------------------------------------------------
#  The core “run a single test” routine
# --------------------------------------------------------------------
run_test() {
    local test_name="$1"
    local cmd="${TESTS[$test_name]}"

    if [[ -z "$cmd" ]]; then
        log_error "Test “${test_name}” is not defined."
        return 1
    fi

    # Build the final command line
    local full_cmd=()
    [[ $ENABLE_MANGOHUD -eq 1 ]] && full_cmd+=("mangohud")
    [[ $ENABLE_GAMEMODERUN -eq 1 ]] && full_cmd+=("gamemoderun")
    [[ $ENABLE_MANGOHUD -eq 1 ]] && full_cmd+=("-m")
    full_cmd+=("${PROTON_VERSION}" "${cmd}")

    log_info "Running test: ${test_name}"
    timeout "${BENCHMARK_TIMEOUT_SECONDS}s" "${full_cmd[@]}"
    local rc=$?

    if (( rc == 124 )); then
        log_error "Test “${test_name}” timed out after ${BENCHMARK_TIMEOUT_SECONDS}s"
        return 124
    elif (( rc != 0 )); then
        log_error "Test “${test_name}” exited with status ${rc}"
        return $rc
    else
        log_info "Test “${test_name}” finished successfully"
        return 0
    fi
}

# --------------------------------------------------------------------
#  Main entry point – parses arguments, creates a log file and executes
# --------------------------------------------------------------------
main() {
    # ----------------------------------------------------------------
    #  Runtime state variables
    # ----------------------------------------------------------------
    local SCRIPT_RUN_TIMESTAMP
    SCRIPT_RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    local LOG_FILE
    LOG_FILE="${SCRIPT_DIR}/${GAME_SHORT_NAME}_benchmark_${SCRIPT_RUN_TIMESTAMP}.txt"

    # ----------------------------------------------------------------
    #  Command‑line parsing (exactly the options you asked for)
    # ----------------------------------------------------------------
    local run_all=0
    local timeout_override=
    local gamemode_requested=0
    local -a selected_tests=()

    while (( $# )); do
        case "$1" in
            -h|--help)          show_help; exit 0 ;;
            --list)             list_tests; exit 0 ;;
            --groups)           list_groups; exit 0 ;;
            --validate-profiles) validate_profiles && exit 0 || exit 1 ;;
            --gamemode)         gamemode_requested=1; shift ;;
            --group)
                [[ -n "$2" ]] || { log_error "--group needs a name"; exit 1; }
                local grp_name="$2"
                if [[ -z "${TEST_GROUPS[$grp_name]:-}" ]]; then
                    log_error "Group “${grp_name}” does not exist"
                    exit 1
                fi
                # Expand the space‑separated list of tests into the array
                read -r -a tmp <<< "${TEST_GROUPS[$grp_name]}"
                selected_tests+=( "${tmp[@]}" )
                shift 2
                ;;
            --timeout-minutes)
                [[ -n "$2" && "$2" =~ ^[0-9]+$ ]] || { log_error "--timeout-minutes requires a numeric argument"; exit 1; }
                BENCHMARK_TIMEOUT_MINUTES="$2"
                BENCHMARK_TIMEOUT_SECONDS=$(( BENCHMARK_TIMEOUT_MINUTES * 60 ))
                shift 2
                ;;
            --all)
                run_all=1
                shift
                ;;
            *)  # any non‑option argument is treated as a test name
                selected_tests+=( "$1" )
                shift
                ;;
        esac
    done

    # ----------------------------------------------------------------
    #  If “--all” was given, replace the explicit list with **all** tests
    # ----------------------------------------------------------------
    if (( run_all )); then
        selected_tests=( "${!TESTS[@]}" )
    fi

    # ----------------------------------------------------------------
    #  If nothing was selected, show help and abort
    # ----------------------------------------------------------------
    if (( ${#selected_tests[@]} == 0 )); then
        log_error "No tests selected.  Use --list or pass test names on the command line."
        show_help
        exit 1
    fi

    # ----------------------------------------------------------------
    #  Enable gamemode if requested
    # ----------------------------------------------------------------
    if (( gamemode_requested )); then
        ENABLE_GAMEMODERUN=1
    fi

    # ----------------------------------------------------------------
    #  Prepare the log file
    # ----------------------------------------------------------------
    {
        echo "=================================================================="
        echo "Assassin’s Creed Valhalla Upscaling Benchmark – $(date)"
        echo "=================================================================="
        echo "Proton version   : ${PROTON_VERSION}"
        echo "Steam library    : ${CUSTOM_LIBRARY_PATH}"
        echo "User settings    : ${USER_SETTINGS_FOLDER}"
        echo "Result source    : ${BENCHMARK_RESULTS_SOURCE_DIR}"
        echo "Result destination: ${BENCHMARK_RESULTS_OUTPUT_DIR}"
        echo "Timeout per test : ${BENCHMARK_TIMEOUT_MINUTES} min (${BENCHMARK_TIMEOUT_SECONDS}s)"
        echo "Gamemode         : $(( ENABLE_GAMEMODERUN ))"
        echo "Mangohud         : $(( ENABLE_MANGOHUD ))"
        echo "=================================================================="
        echo
    } > "${LOG_FILE}"

    # ----------------------------------------------------------------
    #  Run the selected tests one‑by‑one, logging everything through the
    #  shared library (log_to_file writes to both stdout and the log file)
    # ----------------------------------------------------------------
    for test_name in "${selected_tests[@]}"; do
        # Guard against duplicated names / empty entries
        [[ -n "$test_name" ]] || continue

        if [[ -z "${TESTS[$test_name]:-}" ]]; then
            log_error "Test “${test_name}” is not defined in tests.config.sh – skipping"
            continue
        fi

        # Run the test and capture its output in the common log file
        {
            echo "------------------------------------------------------------"
            echo "[$(date '+%Y-%m-%d %H:%M:%S')] Starting test: ${test_name}"
            echo "Command: ${TESTS[$test_name]}"
            echo "------------------------------------------------------------"
        } | tee -a "${LOG_FILE}"

        if run_test "$test_name"; then
            echo "Test “${test_name}” finished – see ${LOG_FILE} for details"
        else
            echo "Test “${test_name}” FAILED – see ${LOG_FILE} for details"
        fi

        echo >> "${LOG_FILE}"
    done

    echo "All requested tests have finished.  Log file: ${LOG_FILE}"
}

# --------------------------------------------------------------------
#  Execute
# --------------------------------------------------------------------
main "$@"