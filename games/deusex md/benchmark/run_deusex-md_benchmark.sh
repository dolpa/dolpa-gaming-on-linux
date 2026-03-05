#!/usr/bin/env bash
# ---------------------------------------------------
# DeusEx - Mankind Divided Benchmark on Ubuntu (Steam)
# ---------------------------------------------------
SYSTEM_NAME_DEFAULT="$(hostname -s 2>/dev/null || echo "default")"
SYSTEM_NAME_DEFAULT="${SYSTEM_NAME_DEFAULT,,}"
SYSTEM_NAME_DEFAULT="$(printf '%s' "$SYSTEM_NAME_DEFAULT" | sed -E 's/pavel//g; s/dolpa//g; s/[-_.]+/-/g; s/^-+|-+$//g')"
if [[ -z "$SYSTEM_NAME_DEFAULT" ]]; then
    SYSTEM_NAME_DEFAULT="default"
fi
SYSTEM_NAME="${DEUSEX_MD_SYSTEM_NAME:-${SYSTEM_NAME:-$SYSTEM_NAME_DEFAULT}}"
SYSTEM_NAME="${SYSTEM_NAME// /_}"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

SYSTEM_CONFIG_DIR="${PROJECT_ROOT_DIR}/system"
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${SYSTEM_NAME}.conf.sh"
SYSTEM_CONFIG_OVERRIDE_FILE="${DEUSEX_MD_BENCHMARK_CONFIG:-}"
DEUSEX_MD_PROTON_VERSION_DEFAULT="GE-Proton10-25"
DEUSEX_MD_LAUNCH_MODE_DEFAULT="proton"

# Built-in defaults (can be overridden by config files below)
GAME_ID=337000
STEAM_PATH="${HOME}/.local/share/Steam"
STEAM_ROOT="${HOME}/.steam/root"
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"
ENABLE_MANGOHUD=1
ENABLE_GAMEMODERUN=0
TERMINATE_STALE_PROCESSES=1
BENCHMARK_TIMEOUT_MINUTES=15
BENCHMARK_TIMEOUT_SECONDS=""
BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS=30
USER_SETTINGS_FOLDER=""
PROTON_USER_REG_FILE="${PROTON_USER_REG_FILE:-}"
BENCHMARK_RESULTS_SOURCE_DIR=""
BENCHMARK_RESULTS_OUTPUT_DIR="${SCRIPT_DIR}/results"
BENCHMARK_ARGS_STRING="${BENCHMARK_ARGS:--benchmark -nolauncher}"
BENCHMARK_INI_ENABLED="${BENCHMARK_INI_ENABLED:-1}"
BENCHMARK_CONFIG_FILE="${BENCHMARK_CONFIG_FILE:-}"
BENCHMARK_RESULTS_FILENAME="${BENCHMARK_RESULTS_FILENAME:-}"
BENCHMARK_LOOP_COUNT="${BENCHMARK_LOOP_COUNT:-1}"
BENCHMARK_CAPTURE_TIMEOUT_SECONDS="${BENCHMARK_CAPTURE_TIMEOUT_SECONDS:-120}"
BENCHMARK_QUIT_WHEN_LOADED="${BENCHMARK_QUIT_WHEN_LOADED:-0}"
BENCHMARK_QUIT_AFTERWARDS="${BENCHMARK_QUIT_AFTERWARDS:-1}"
BENCHMARK_RESULTS_TO_FILE="${BENCHMARK_RESULTS_TO_FILE:-1}"
BENCHMARK_SHOW_STATISTICS="${BENCHMARK_SHOW_STATISTICS:-1}"
BENCHMARK_RESULTS_ADD_DXDIAG="${BENCHMARK_RESULTS_ADD_DXDIAG:-1}"
BENCHMARK_AUTOLOAD_SPAWNPOINT_ID="${BENCHMARK_AUTOLOAD_SPAWNPOINT_ID:-}"
BENCHMARK_SCENE="${BENCHMARK_SCENE:-assembly:/scenes/game/99_benchmark/ben_master.entity}"
RESULT_COPY_RETRY_SECONDS="${RESULT_COPY_RETRY_SECONDS:-15}"

BENCHMARK_INI_BACKUP_FILE=""
BENCHMARK_INI_CREATED="0"

if [[ -f "$SYSTEM_CONFIG_LOCAL_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_LOCAL_FILE"
fi

if [[ -n "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
    if [[ ! -f "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
        echo "Error: DEUSEX_MD_BENCHMARK_CONFIG file not found: $SYSTEM_CONFIG_OVERRIDE_FILE" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_OVERRIDE_FILE"
fi

# Proton selection precedence:
# 1) DEUSEX_MD_PROTON_VERSION (game-specific override)
# 2) PROTON_VERSION (shared system default)
# 3) DEUSEX_MD_PROTON_VERSION_DEFAULT (game fallback)
PROTON_VERSION="${DEUSEX_MD_PROTON_VERSION:-${PROTON_VERSION:-$DEUSEX_MD_PROTON_VERSION_DEFAULT}}"

# Launch mode selection precedence:
# 1) DEUSEX_MD_LAUNCH_MODE (game-specific override)
# 2) DEUSEX_MD_LAUNCH_MODE_DEFAULT (game default)
DEUSEX_MD_LAUNCH_MODE="${DEUSEX_MD_LAUNCH_MODE:-$DEUSEX_MD_LAUNCH_MODE_DEFAULT}"
DEUSEX_MD_LAUNCH_MODE="${DEUSEX_MD_LAUNCH_MODE,,}"

case "$DEUSEX_MD_LAUNCH_MODE" in
    proton)
        ;;
    native)
        echo "Error: native launch mode is not supported for Deus Ex MD benchmark. Use proton." >&2
        exit 1
        ;;
    *)
        echo "Error: invalid DEUSEX_MD_LAUNCH_MODE '$DEUSEX_MD_LAUNCH_MODE'. Supported value: proton" >&2
        exit 1
        ;;
esac

INITIAL_LAUNCH_MODE="$DEUSEX_MD_LAUNCH_MODE"
for cli_arg in "$@"; do
    case "$cli_arg" in
        --proton)
            INITIAL_LAUNCH_MODE="proton"
            ;;
    esac
done

if [[ -z "${BENCHMARK_TIMEOUT_SECONDS:-}" ]]; then
    BENCHMARK_TIMEOUT_SECONDS=$((BENCHMARK_TIMEOUT_MINUTES * 60))
fi

if [[ -z "${USER_SETTINGS_FOLDER:-}" ]]; then
    USER_SETTINGS_FOLDER="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/AppData/Roaming/Eidos Montreal/Deus Ex Mankind Divided"
fi

if [[ -z "${PROTON_USER_REG_FILE:-}" ]]; then
    PROTON_USER_REG_FILE="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/user.reg"
fi

if [[ -z "${BENCHMARK_RESULTS_SOURCE_DIR:-}" ]]; then
    BENCHMARK_RESULTS_SOURCE_DIR="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Deus Ex -  Mankind Divided/benchmarkResults/"
fi

SCRIPT_RUN_TIMESTAMP=""                                 # Set once in main and reused by all tests in the same run
GPU_METADATA_TAG="unknown-gpu_unknown-vram_unknown-driver" # Set once in main and reused in result filenames

BASH_UTILS_LOADER="${SCRIPT_DIR}/../../../dolpa-bash-utils/bash-utils.sh"
if [[ ! -f "$BASH_UTILS_LOADER" ]]; then
    echo "Error: dolpa-bash-utils loader not found: $BASH_UTILS_LOADER" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "$BASH_UTILS_LOADER"

# Define available test configurations
declare -A TESTS

# Load base test definitions from external config (Proton-only)
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.proton.conf.sh"
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/proton-test.conf.sh"
fi
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/proton.tests.conf.sh"
fi
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
fi
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    log_error "Tests config file not found for launch mode '${INITIAL_LAUNCH_MODE}'."
    exit 1
fi
# shellcheck source=/dev/null
source "$TESTS_CONFIG_FILE"

# Keep only proton tests even when fallback config includes native ones.
for test_name in "${!TESTS[@]}"; do
    if [[ "$test_name" != proton-* ]]; then
        unset 'TESTS[$test_name]'
    fi
done

# Auto-add frame generation test variants for base tests when a matching profile exists.
# Supported suffix:
#   -fg
for base_test_name in "${!TESTS[@]}"; do
    if [[ "$base_test_name" == *-fg* ]]; then
        continue
    fi

    for fg_suffix in "fg"; do
        fg_test_name="${base_test_name}-${fg_suffix}"
        fg_profile_file="${SCRIPT_DIR}/profiles/UserSettings.${fg_test_name}.json"

        if [[ -f "$fg_profile_file" && ! "${TESTS[$fg_test_name]+isset}" ]]; then
            read -r mode resolution quality ray_tracing frame_generation <<< "${TESTS[$base_test_name]}"
            TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing on"
        fi
    done
done

# Predefined test groups for common scenarios
declare -A TEST_GROUPS

TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.proton.conf.sh"
if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
    TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/proton-groups.conf.sh"
fi
if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
    TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/proton.groups.conf.sh"
fi
if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
    TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.conf.sh"
fi
if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
    log_error "Test groups config file not found for launch mode '${INITIAL_LAUNCH_MODE}'."
    exit 1
fi
# shellcheck source=/dev/null
source "$TEST_GROUPS_CONFIG_FILE"

# Keep only proton tests inside groups; drop empty groups.
for group_name in "${!TEST_GROUPS[@]}"; do
    read -ra group_tests <<< "${TEST_GROUPS[$group_name]}"
    filtered_group_tests=()
    for test_name in "${group_tests[@]}"; do
        if [[ "$test_name" == proton-* ]]; then
            filtered_group_tests+=("$test_name")
        fi
    done

    if [[ ${#filtered_group_tests[@]} -eq 0 ]]; then
        unset 'TEST_GROUPS[$group_name]'
    else
        TEST_GROUPS["$group_name"]="${filtered_group_tests[*]}"
    fi
done

build_quick_resolution_variant_groups() {
    add_test_and_rt_pair_if_available() {
        local target_array_name="$1"
        local mapped_test_name="$2"

        if [[ -z "${TESTS[$mapped_test_name]+isset}" ]]; then
            return
        fi

        eval "$target_array_name+=(\"$mapped_test_name\")"

        local counterpart_test_name=""
        if [[ "$mapped_test_name" == *-rt-off* ]]; then
            counterpart_test_name="${mapped_test_name/-rt-off/-rt-on}"
        elif [[ "$mapped_test_name" == *-rt-on* ]]; then
            counterpart_test_name="${mapped_test_name/-rt-on/-rt-off}"
        fi

        if [[ -n "$counterpart_test_name" && -n "${TESTS[$counterpart_test_name]+isset}" ]]; then
            eval "$target_array_name+=(\"$counterpart_test_name\")"
        fi
    }

    local source_group_name
    for source_group_name in "${!TEST_GROUPS[@]}"; do
        [[ "$source_group_name" == 4k-quick-* ]] || continue

        local group_suffix="${source_group_name#4k-quick-}"
        local target_group_1080p="1080p-quick-${group_suffix}"
        local target_group_1440p="1440p-quick-${group_suffix}"

        read -ra source_tests <<< "${TEST_GROUPS[$source_group_name]}"

        local -a mapped_1080p_tests=()
        local -a mapped_1440p_tests=()
        local -A seen_1080p_tests=()
        local -A seen_1440p_tests=()
        local source_test mapped_test

        for source_test in "${source_tests[@]}"; do
            mapped_test="${source_test//-4k-/-1080p-}"
            add_test_and_rt_pair_if_available "mapped_1080p_tests" "$mapped_test"

            mapped_test="${source_test//-4k-/-1440p-}"
            add_test_and_rt_pair_if_available "mapped_1440p_tests" "$mapped_test"
        done

        local -a deduped_1080p_tests=()
        for mapped_test in "${mapped_1080p_tests[@]}"; do
            if [[ -z "${seen_1080p_tests[$mapped_test]+isset}" ]]; then
                deduped_1080p_tests+=("$mapped_test")
                seen_1080p_tests["$mapped_test"]=1
            fi
        done

        local -a deduped_1440p_tests=()
        for mapped_test in "${mapped_1440p_tests[@]}"; do
            if [[ -z "${seen_1440p_tests[$mapped_test]+isset}" ]]; then
                deduped_1440p_tests+=("$mapped_test")
                seen_1440p_tests["$mapped_test"]=1
            fi
        done

        if [[ ${#deduped_1080p_tests[@]} -gt 0 ]]; then
            TEST_GROUPS["$target_group_1080p"]="${deduped_1080p_tests[*]}"
        fi

        if [[ ${#deduped_1440p_tests[@]} -gt 0 ]]; then
            TEST_GROUPS["$target_group_1440p"]="${deduped_1440p_tests[*]}"
        fi
    done
}

augment_existing_groups_with_fg_variants() {
    for group_name in "${!TEST_GROUPS[@]}"; do
        if [[ "$group_name" == "quick-4k" || "$group_name" == 4k-quick-* ]]; then
            continue
        fi

        read -ra group_tests <<< "${TEST_GROUPS[$group_name]}"

        local -a updated_group_tests=()
        local -A seen_tests=()

        for test_name in "${group_tests[@]}"; do
            if [[ -n "$test_name" && -z "${seen_tests[$test_name]+isset}" ]]; then
                updated_group_tests+=("$test_name")
                seen_tests["$test_name"]=1
            fi

            if [[ "$test_name" != *-fg* ]]; then
                local fg_variant
                for fg_suffix in "fg"; do
                    fg_variant="${test_name}-${fg_suffix}"
                    if [[ -n "${TESTS[$fg_variant]+isset}" && -z "${seen_tests[$fg_variant]+isset}" ]]; then
                        updated_group_tests+=("$fg_variant")
                        seen_tests["$fg_variant"]=1
                    fi
                done
            fi
        done

        TEST_GROUPS["$group_name"]="${updated_group_tests[*]}"
    done
}

build_dynamic_groups() {
    local -a tests_1080p=()
    local -a tests_1440p=()
    local -a tests_4k=()
    local -a tests_rt=()

    for test_name in "${!TESTS[@]}"; do
        [[ "$test_name" == *-1080p-* ]] && tests_1080p+=("$test_name")
        [[ "$test_name" == *-1440p-* ]] && tests_1440p+=("$test_name")
        [[ "$test_name" == *-4k-* ]] && tests_4k+=("$test_name")
        [[ "$test_name" =~ -rt-(on|psycho) ]] && tests_rt+=("$test_name")
    done

    if [[ ${#tests_1080p[@]} -gt 0 ]]; then
        IFS=$'\n' tests_1080p=($(sort <<<"${tests_1080p[*]}"))
        unset IFS
        TEST_GROUPS["all-1080p-tests"]="${tests_1080p[*]}"
    fi

    if [[ ${#tests_1440p[@]} -gt 0 ]]; then
        IFS=$'\n' tests_1440p=($(sort <<<"${tests_1440p[*]}"))
        unset IFS
        TEST_GROUPS["all-1440p-tests"]="${tests_1440p[*]}"
    fi

    if [[ ${#tests_4k[@]} -gt 0 ]]; then
        IFS=$'\n' tests_4k=($(sort <<<"${tests_4k[*]}"))
        unset IFS
        TEST_GROUPS["all-4k-tests"]="${tests_4k[*]}"
    fi

    if [[ ${#tests_rt[@]} -gt 0 ]]; then
        IFS=$'\n' tests_rt=($(sort <<<"${tests_rt[*]}"))
        unset IFS
        TEST_GROUPS["all-rt-tests"]="${tests_rt[*]}"
    fi
}

augment_existing_groups_with_fg_variants
build_quick_resolution_variant_groups
build_dynamic_groups

# Function to show help
show_help() {
    echo "Deus EX - Mankind Divided Benchmark Script"
    echo "Usage: $0 [OPTIONS] [TEST_NAME...]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h          Show this help message"
    echo "  --all              Run all available tests"
    echo "  --list             List all available test names"
    echo "  --groups           List predefined test groups"
    echo "  --group GROUP      Run a predefined test group"
    echo "  --timeout-minutes  MIN  Per-test timeout in minutes (default: 15)"
    echo "  --native           Unsupported (kept for explicit error message)"
    echo "  --proton           Force Proton launch mode"
    echo "  --benchmark-args   ARGS  Override benchmark launch args (default: -benchmark -nolauncher)"
    echo "  --no-benchmark-ini Disable benchmark.ini generation"
    echo "  --no-kill-stale    Do not terminate stale DXMD/Proton processes"
    echo "  --gamemode         Run game launch through gamemoderun"
    echo "  --validate-profiles Check whether profile files exist for tests"
    echo ""
    echo "SYSTEM CONFIG FILES (loaded in order):"
    echo "  1) ${SYSTEM_CONFIG_LOCAL_FILE} (optional, selected by SYSTEM_NAME=${SYSTEM_NAME})"
    echo "  2) DEUSEX_MD_BENCHMARK_CONFIG=/path/to/file.conf.sh (optional override)"
    echo ""
    echo "System selection override:"
    echo "  DEUSEX_MD_SYSTEM_NAME=MY_MACHINE $0 --group quick-4k"
    echo ""
    echo "Launch mode override:"
    echo "  Native mode is not supported for this benchmark runner"
    echo "  DEUSEX_MD_LAUNCH_MODE=proton $0 --group quick"
    echo "  DEUSEX_MD_PROTON_VERSION=${PROTON_VERSION} $0 --proton --group quick"
    echo ""
    echo "TESTS:"
    echo "  If no test names are specified, runs default test: proton-1080p-low"
    echo "  Multiple test names can be specified to run them sequentially"
    echo ""
    echo "TEST GROUPS (active launch mode: ${INITIAL_LAUNCH_MODE}):"
    for group_name in "${!TEST_GROUPS[@]}"; do
        echo "  $group_name: ${TEST_GROUPS[$group_name]}"
    done | sort
    echo ""
    echo "Available tests (active launch mode: ${INITIAL_LAUNCH_MODE}):"
    for test_name in "${!TESTS[@]}"; do
        local params=(${TESTS[$test_name]})
        printf "  %-25s %s %s %s RT:%s FG:%s\n" "$test_name" "${params[0]}" "${params[1]}" "${params[2]}" "${params[3]}" "${params[4]}"
    done | sort
    echo ""
    echo "Examples:"
    echo "  $0 --help"
    echo "  $0 --list"
    echo "  $0 --groups"
    echo "  $0 --validate-profiles"
    echo "  $0 --all"
    echo "  $0 --group quick"
    echo "  $0 --group quick --group quick-4k"
    echo "  $0 --group quick-4k"
    echo "  $0 --gamemode --group quick"
    echo "  $0 proton-1080p-high"
    echo ""
    echo "PROFILE FILES:"
    echo "  Proton mode profile per test:"
    echo "    {TEST_NAME}.user.reg"
    echo "    or without RT suffix: {TEST_NAME without -rt-*}.user.reg"
    echo "    applied to: ${PROTON_USER_REG_FILE}"
    echo "  Example (proton): proton-4k-high.user.reg"
    echo ""
}

validate_profiles() {
    local missing_count=0

    if [[ ! -d "${SCRIPT_DIR}/profiles" ]]; then
        log_error "Profiles directory not found: ${SCRIPT_DIR}/profiles"
        return 1
    fi

    log_info "Validating profile files in ${SCRIPT_DIR}/profiles ..."
    for test_name in "${!TESTS[@]}"; do
        if [[ "$test_name" != proton-* ]]; then
            continue
        fi

        local test_name_without_rt="${test_name/-rt-off/}"
        test_name_without_rt="${test_name_without_rt/-rt-on/}"
        test_name_without_rt="${test_name_without_rt/-rt-psycho/}"
        local profile_file="${SCRIPT_DIR}/profiles/${test_name}.user.reg"
        local fallback_profile_file="${SCRIPT_DIR}/profiles/${test_name_without_rt}.user.reg"

        if [[ ! -f "$profile_file" && ! -f "$fallback_profile_file" ]]; then
            log_warning "Missing: ${test_name}.user.reg (or ${test_name_without_rt}.user.reg)"
            missing_count=$((missing_count + 1))
        fi
    done

    if [[ $missing_count -eq 0 ]]; then
        log_success "Profile validation passed: all test profiles exist."
        return 0
    fi

    log_error "Profile validation failed: ${missing_count} missing profile file(s)."
    return 1
}

# Function to list available tests
list_tests() {
    echo "Available test configurations:"
    for test_name in "${!TESTS[@]}"; do
        echo "  $test_name"
    done | sort
}

# Function to list test groups
list_groups() {
    echo "Available test groups:"
    for group_name in "${!TEST_GROUPS[@]}"; do
        echo "  $group_name: ${TEST_GROUPS[$group_name]}"
    done | sort
}

log_to_file() {
    local level="$1"
    local log_file="$2"
    shift 2
    local message="$*"

    case "$level" in
        success) log_success "$message" ;;
        warning) log_warning "$message" ;;
        error) log_error "$message" ;;
        *) log_info "$message" ;;
    esac

    if [[ -n "$log_file" ]]; then
        printf '%s\n' "$message" >> "$log_file"
    fi
}

normalize_seconds_var() {
    local var_name="$1"
    local raw_value="${!var_name:-}"
    local normalized_value="${raw_value%s}"

    if [[ -z "$normalized_value" || ! "$normalized_value" =~ ^[0-9]+$ ]]; then
        log_error "$var_name must be an integer number of seconds (or end with 's'), got: '$raw_value'"
        exit 1
    fi

    printf -v "$var_name" '%s' "$normalized_value"
}

normalize_zero_one_var() {
    local var_name="$1"
    local raw_value="${!var_name:-}"

    if [[ "$raw_value" != "0" && "$raw_value" != "1" ]]; then
        log_error "$var_name must be 0 or 1, got: '$raw_value'"
        exit 1
    fi
}

normalize_positive_int_var() {
    local var_name="$1"
    local raw_value="${!var_name:-}"

    if [[ -z "$raw_value" || ! "$raw_value" =~ ^[0-9]+$ || "$raw_value" -le 0 ]]; then
        log_error "$var_name must be a positive integer, got: '$raw_value'"
        exit 1
    fi
}

kill_stale_processes() {
    # Avoid broad 'proton' matching here because it can match this script's
    # own command-line arguments (for example, '--proton').
    pkill -f "DXMD.exe|DXMD|wineserver" >/dev/null 2>&1 || true
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
    # Plain filename is more reliable than forcing C:\ under Proton.
    echo "ResultsFileName=${BENCHMARK_RESULTS_FILENAME}"
    echo "LoopCount=${BENCHMARK_LOOP_COUNT}"
    echo "TimeOut=${BENCHMARK_CAPTURE_TIMEOUT_SECONDS}"
    if [[ -n "$BENCHMARK_AUTOLOAD_SPAWNPOINT_ID" ]]; then
        echo "AutoLoadSpawnPointID=${BENCHMARK_AUTOLOAD_SPAWNPOINT_ID}"
    fi
}

prepare_benchmark_ini() {
    local log="$1"

    if [[ "$BENCHMARK_INI_ENABLED" != "1" ]]; then
        log_to_file info "$log" "BENCHMARK_INI_ENABLED=0, skipping benchmark.ini generation"
        return 0
    fi

    mkdir -p "$(dirname "$BENCHMARK_CONFIG_FILE")"

    BENCHMARK_INI_BACKUP_FILE=""
    BENCHMARK_INI_CREATED="0"

    if [[ -f "$BENCHMARK_CONFIG_FILE" ]]; then
        BENCHMARK_INI_BACKUP_FILE="${BENCHMARK_CONFIG_FILE}.bak.${SCRIPT_RUN_TIMESTAMP}"
        cp "$BENCHMARK_CONFIG_FILE" "$BENCHMARK_INI_BACKUP_FILE"
        log_to_file info "$log" "Backed up existing benchmark.ini to $BENCHMARK_INI_BACKUP_FILE"
    fi

    {
        write_benchmark_ini_block ""
        echo
        write_benchmark_ini_block "benchmark"
        echo
        write_benchmark_ini_block "main"
    } > "$BENCHMARK_CONFIG_FILE"

    BENCHMARK_INI_CREATED="1"
    log_to_file info "$log" "Generated benchmark.ini: $BENCHMARK_CONFIG_FILE"
}

restore_benchmark_ini() {
    local log="$1"

    if [[ "$BENCHMARK_INI_CREATED" != "1" ]]; then
        return 0
    fi

    if [[ -n "$BENCHMARK_INI_BACKUP_FILE" && -f "$BENCHMARK_INI_BACKUP_FILE" ]]; then
        mv "$BENCHMARK_INI_BACKUP_FILE" "$BENCHMARK_CONFIG_FILE"
        log_to_file info "$log" "Restored original benchmark.ini"
    else
        # rm -f "$BENCHMARK_CONFIG_FILE"
        log_to_file info "$log" "Removed generated benchmark.ini"
    fi

    BENCHMARK_INI_CREATED="0"
}

sanitize_filename_segment() {
    local value="$1"
    value="$(echo "$value" | tr '[:upper:]' '[:lower:]')"
    value="$(echo "$value" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
    value="$(echo "$value" | sed 's/[[:space:]]\+/_/g')"
    value="$(echo "$value" | sed 's/[^a-z0-9._-]/-/g')"
    value="$(echo "$value" | sed 's/[-_][-_]*/-/g')"
    value="$(echo "$value" | sed 's/^[-_.]*//;s/[-_.]*$//')"
    if [[ -z "$value" ]]; then
        value="unknown"
    fi
    echo "$value"
}

detect_gpu_metadata() {
    local gpu_model="unknown-gpu"
    local gpu_vram="unknown-vram"
    local gpu_driver="unknown-driver"

    if command -v nvidia-smi >/dev/null 2>&1; then
        local gpu_line
        gpu_line="$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1)"
        if [[ -n "$gpu_line" ]]; then
            local model_raw vram_raw driver_raw
            IFS=',' read -r model_raw vram_raw driver_raw <<< "$gpu_line"
            model_raw="$(echo "$model_raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            vram_raw="$(echo "$vram_raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"
            driver_raw="$(echo "$driver_raw" | sed 's/^[[:space:]]*//;s/[[:space:]]*$//')"

            [[ -n "$model_raw" ]] && gpu_model="$model_raw"
            [[ -n "$vram_raw" ]] && gpu_vram="${vram_raw}mb"
            [[ -n "$driver_raw" ]] && gpu_driver="$driver_raw"
        fi
    elif command -v lspci >/dev/null 2>&1; then
        local lspci_line
        lspci_line="$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1)"
        if [[ -n "$lspci_line" ]]; then
            gpu_model="$lspci_line"
        fi
    fi

    GPU_METADATA_TAG="$(sanitize_filename_segment "$gpu_model")_$(sanitize_filename_segment "$gpu_vram")_$(sanitize_filename_segment "$gpu_driver")"
}

copy_benchmark_result_file() {
    local test_name="$1"
    local log="$2"
    local game_path="$3"
    local game_cwd="$4"
    local search_since_epoch="${5:-0}"
    local output_dir="$BENCHMARK_RESULTS_OUTPUT_DIR"
    local steam_library_path="${CUSTOM_LIBRARY_PATH}"
    if [[ "$game_path" == */steamapps/common/* ]]; then
        steam_library_path="${game_path%%/steamapps/common/*}"
    fi

    local docs_dir="${steam_library_path}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Deus Ex -  Mankind Divided"
    local docs_dir_alt="${steam_library_path}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/My Documents/Deus Ex -  Mankind Divided"

    local -a source_dir_candidates=(
        "$BENCHMARK_RESULTS_SOURCE_DIR"
        "${docs_dir}"
        "${docs_dir_alt}"
        "${HOME}/.local/share/feral-interactive/Deus Ex -  Mankind Divided/SaveData"
        "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Deus Ex -  Mankind Divided"
        "${STEAM_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Deus Ex -  Mankind Divided"
        "${STEAM_PATH}/steamapps/common/Deus Ex Mankind Divided/"
        "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/AppData/Roaming/Eidos Montreal/Deus Ex Mankind Divided"
    )

    mkdir -p "$output_dir"

    if [[ -z "$SCRIPT_RUN_TIMESTAMP" ]]; then
        SCRIPT_RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    fi

    log_to_file info "$log" "Benchmark result search epoch: ${search_since_epoch}"
    log_to_file info "$log" "Benchmark source candidates:"

    local -a existing_source_dirs=()
    local -A seen_existing_source_dirs=()
    local candidate_dir
    for candidate_dir in "${source_dir_candidates[@]}"; do
        if [[ -z "$candidate_dir" ]]; then
            continue
        fi

        if [[ -d "$candidate_dir" ]]; then
            log_to_file info "$log" "  [found] $candidate_dir"
            if [[ -z "${seen_existing_source_dirs[$candidate_dir]+isset}" ]]; then
                existing_source_dirs+=("$candidate_dir")
                seen_existing_source_dirs["$candidate_dir"]=1
            fi
        else
            log_to_file info "$log" "  [missing] $candidate_dir"
        fi
    done

    if [[ ${#existing_source_dirs[@]} -eq 0 ]]; then
        log_to_file warning "$log" "No benchmark source directories exist."
        return 0
    fi

    if [[ -n "$BENCHMARK_RESULTS_FILENAME" ]]; then
        local -a csv_candidates=(
            "${game_path}/${BENCHMARK_RESULTS_FILENAME}"
            "${game_cwd}/${BENCHMARK_RESULTS_FILENAME}"
            "${docs_dir}/${BENCHMARK_RESULTS_FILENAME}"
            "${docs_dir_alt}/${BENCHMARK_RESULTS_FILENAME}"
        )

        for candidate_dir in "${existing_source_dirs[@]}"; do
            csv_candidates+=("${candidate_dir}/${BENCHMARK_RESULTS_FILENAME}")
        done

        local candidate=""
        log_to_file info "$log" "Searching for benchmark CSV: ${BENCHMARK_RESULTS_FILENAME}"
        for candidate in "${csv_candidates[@]}"; do
            if [[ -f "$candidate" ]]; then
                if [[ "$search_since_epoch" -gt 0 ]]; then
                    local candidate_mtime_epoch
                    candidate_mtime_epoch="$(stat -c %Y "$candidate" 2>/dev/null || echo 0)"
                    if [[ "$candidate_mtime_epoch" -lt "$search_since_epoch" ]]; then
                        log_to_file info "$log" "  [stale] $candidate (mtime: ${candidate_mtime_epoch})"
                        continue
                    fi
                fi

                local csv_destination_file="$output_dir/${GAME_ID}_result_${test_name}_${GPU_METADATA_TAG}_${SCRIPT_RUN_TIMESTAMP}_$(basename "$candidate")"
                cp "$candidate" "$csv_destination_file"
                if [[ $? -eq 0 ]]; then
                    log_to_file info "$log" "Using benchmark CSV source: $candidate"
                    log_to_file success "$log" "Copied benchmark CSV result: $csv_destination_file"
                    return 0
                fi
            else
                log_to_file info "$log" "  [not found] $candidate"
            fi
        done

        if [[ "$search_since_epoch" -gt 0 ]]; then
            log_to_file warning "$log" "No fresh benchmark CSV found since epoch ${search_since_epoch}. Continuing with summary.json search."
        fi
    fi

    log_to_file info "$log" "Searching for any fresh CSV benchmark artifact..."
    local fallback_csv_file=""
    fallback_csv_file="$(
        for candidate_dir in "${existing_source_dirs[@]}"; do
            find "$candidate_dir" -type f -name '*.csv' -printf '%T@ %p\n' 2>/dev/null
        done | awk -v since="$search_since_epoch" 'since <= 0 || $1 >= since' | sort -nr | head -n1 | cut -d' ' -f2-
    )"

    if [[ -z "$fallback_csv_file" && "$search_since_epoch" -gt 0 ]]; then
        fallback_csv_file="$(
            for candidate_dir in "${existing_source_dirs[@]}"; do
                find "$candidate_dir" -type f -name '*.csv' -printf '%T@ %p\n' 2>/dev/null
            done | sort -nr | head -n1 | cut -d' ' -f2-
        )"
        if [[ -n "$fallback_csv_file" ]]; then
            log_to_file warning "$log" "No fresh CSV found since epoch ${search_since_epoch}; falling back to latest available CSV."
        fi
    fi

    if [[ -n "$fallback_csv_file" && -f "$fallback_csv_file" ]]; then
        local fallback_csv_destination="$output_dir/${GAME_ID}_result_${test_name}_${GPU_METADATA_TAG}_${SCRIPT_RUN_TIMESTAMP}_$(basename "$fallback_csv_file")"
        cp "$fallback_csv_file" "$fallback_csv_destination"
        if [[ $? -eq 0 ]]; then
            log_to_file info "$log" "Using fallback benchmark CSV source: $fallback_csv_file"
            log_to_file success "$log" "Copied benchmark CSV result: $fallback_csv_destination"
            return 0
        fi
    fi

    log_to_file info "$log" "Searching for summary.json in benchmark_* directories..."
    local source_file=""
    source_file="$(
        for candidate_dir in "${existing_source_dirs[@]}"; do
            find "$candidate_dir" -type f -path '*/benchmark_*/summary.json' -printf '%T@ %p\n' 2>/dev/null
        done | awk -v since="$search_since_epoch" 'since <= 0 || $1 >= since' | sort -nr | head -n1 | cut -d' ' -f2-
    )"

    if [[ -z "$source_file" && "$search_since_epoch" -gt 0 ]]; then
        source_file="$(
            for candidate_dir in "${existing_source_dirs[@]}"; do
                find "$candidate_dir" -type f -path '*/benchmark_*/summary.json' -printf '%T@ %p\n' 2>/dev/null
            done | sort -nr | head -n1 | cut -d' ' -f2-
        )"
        if [[ -n "$source_file" ]]; then
            log_to_file warning "$log" "No fresh summary.json found since epoch ${search_since_epoch}; falling back to latest available file."
        fi
    fi

    if [[ -z "$source_file" || ! -f "$source_file" ]]; then
        log_to_file warning "$log" "No benchmark result artifact found (CSV or summary.json)."
        return 0
    fi

    local destination_file="$output_dir/${GAME_ID}_result_${test_name}_${GPU_METADATA_TAG}_${SCRIPT_RUN_TIMESTAMP}.json"
    cp "$source_file" "$destination_file"
    if [[ $? -eq 0 ]]; then
        log_to_file info "$log" "Using benchmark summary source: $source_file"
        log_to_file success "$log" "Copied benchmark result: $destination_file"
    else
        log_to_file warning "$log" "Failed to copy benchmark result from $source_file"
    fi
}


# Function to apply settings based on launch mode and quality preset
# $1 - mode, supported value: proton
# $2 - resolution, e.g., 2560x1440
# $3 - quality preset, e.g., low, medium, high, ultra, custom
# $4 - ray tracing, e.g., off, on, psycho
# $5 - frame generation, e.g., off, on, auto
# $6 - log file, for logging errors and info
# $7 - output array name for launch args, passed by reference
# $8 - optional test name for profile matching (preferred method), if not provided will fallback to parameter-based naming
apply_setting() {
    local mode=$1
    local resolution=$2
    local quality_preset=$3
    local ray_tracing=$4
    local frame_generation=$5
    local log=$6
    local output_array_name=$7
    local test_name=${8:-""}
    local -n launch_args_ref="$output_array_name"

    local original_mode="$mode"
    local profile_dir="${SCRIPT_DIR}/profiles"
    local target_settings_file=""

    target_settings_file="$PROTON_USER_REG_FILE"
    # Validate mode and extract base mode for profile matching
    case "$mode" in
        proton)
            ;;
        *)
                log_to_file error "$log" "Unsupported mode '$mode'. Supported modes:"
                log_to_file error "$log" "  proton"
            return 1
            ;;
    esac
    # Validate resolution format (e.g., 2560x1440)
    if [[ ! "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
        log_to_file error "$log" "Invalid resolution '$resolution'. Expected WIDTHxHEIGHT (e.g., 2560x1440)."
        return 1
    fi
    # Validate quality preset
    case "$quality_preset" in
        low|medium|high|very-high|ultra|custom)
            ;;
        *)
            log_to_file error "$log" "Unsupported quality preset '$quality_preset'. Supported: low, medium, high, very-high, ultra, custom"
            return 1
            ;;
    esac
    # Validate ray tracing options
    case "$ray_tracing" in
        off|on|psycho)
            ;;
        *)
            log_to_file error "$log" "Unsupported ray tracing '$ray_tracing'. Supported: off, on, psycho"
            return 1
            ;;
    esac
    # Validate frame generation options
    case "$frame_generation" in
        off|on|auto|x2|x4)
            ;;
        *)
            log_to_file error "$log" "Unsupported frame generation '$frame_generation'. Supported: off, on, auto, x2, x4"
            return 1
            ;;
    esac
    # Set launch arguments based on mode and resolution
    launch_args_ref=(--resolution "$resolution")

    if [[ ! -d "$profile_dir" ]]; then
        log_to_file error "$log" "Profiles directory does not exist: $profile_dir"
        return 1
    fi

    # Look for exact profile match based on test name or parameters
    local exact_profile=""
    local fallback_profile=""
    local test_name_without_rt="$test_name"
    test_name_without_rt="${test_name_without_rt/-rt-off/}"
    test_name_without_rt="${test_name_without_rt/-rt-on/}"
    test_name_without_rt="${test_name_without_rt/-rt-psycho/}"
    
    if [[ -n "$test_name" ]]; then
        exact_profile="${profile_dir}/${test_name}.user.reg"
        fallback_profile="${profile_dir}/${test_name_without_rt}.user.reg"
    else
        exact_profile="${profile_dir}/${original_mode}.${quality_preset}.rt-${ray_tracing}.fg-${frame_generation}.user.reg"
        fallback_profile=""
    fi

    if [[ ! -f "$exact_profile" && -n "$fallback_profile" && -f "$fallback_profile" ]]; then
        exact_profile="$fallback_profile"
    fi

    # Check if target settings location exists
    local target_parent_dir
    target_parent_dir="$(dirname "$target_settings_file")"
    if [[ ! -d "$target_parent_dir" ]]; then
        log_to_file error "$log" "Proton settings directory does not exist: $target_parent_dir"
        log_to_file warning "$log" "Please ensure the game has been run at least once to create the Proton prefix."
        return 1
    fi

    # Check if the exact profile file exists and copy it to the target settings location
    if [[ -f "$exact_profile" ]]; then
        cp "$exact_profile" "$target_settings_file"
        if [[ $? -eq 0 ]]; then
            log_to_file success "$log" "Applied settings profile: $exact_profile"
        else
            log_to_file error "$log" "Failed to copy settings profile to $target_settings_file"
            return 1
        fi
    else
        log_to_file error "$log" "Required settings profile not found: $exact_profile"
        if [[ -n "$fallback_profile" ]]; then
            log_to_file error "$log" "Fallback profile also not found: $fallback_profile"
        fi
        if [[ -n "$test_name" ]]; then
            log_to_file error "$log" "Expected profile file: ${test_name}.user.reg (or ${test_name_without_rt}.user.reg)"
        else
            log_to_file error "$log" "Available parameters: mode=$original_mode, quality=$quality_preset, ray_tracing=$ray_tracing, frame_generation=$frame_generation"
        fi
        log_to_file warning "$log" "Please ensure the exact profile file exists in $profile_dir"
        return 1
    fi

    # Verify that settings file exists after applying profile
    if [[ ! -f "$target_settings_file" ]]; then
        log_to_file error "$log" "Settings file does not exist at $target_settings_file"
        log_to_file warning "$log" "Please ensure a valid settings profile was applied or the game has been configured."
        return 1
    fi
    # Log the applied settings for reference
    log_to_file info "$log" "Applied settings => mode=$original_mode resolution=$resolution quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation"
    if [[ -n "$test_name" ]]; then
        log_to_file info "$log" "Profile selection method: test name ($test_name)"
    else
        log_to_file info "$log" "Profile selection method: parameter-based"
    fi
    return 0
}

# Function to run a specific test configuration
run_test() {
    local test_name="$1"
    local logfile="$2"
    local test_index="${3:-0}"
    local total_tests="${4:-0}"     # for logging purposes, if available
    
    if [[ ! "${TESTS[$test_name]+isset}" ]]; then
        log_to_file error "$logfile" "Unknown test '$test_name'. Use --list to see available tests."
        return 1
    fi
    
    local params=(${TESTS[$test_name]})
    local mode="${params[0]}"
    local resolution="${params[1]}"
    local quality="${params[2]}"
    local ray_tracing="${params[3]}"
    local frame_generation="${params[4]}"
    
    if [[ "$test_index" -gt 0 && "$total_tests" -gt 0 ]]; then
        log_to_file info "$logfile" "Running test ($test_index/$total_tests): $test_name"
    else
        log_to_file info "$logfile" "Running test: $test_name"
    fi
    log_to_file info "$logfile" "Parameters: mode=$mode resolution=$resolution quality=$quality ray_tracing=$ray_tracing frame_generation=$frame_generation"
    # Apply settings and run benchmark
    if run_bench "$mode" "$resolution" "$logfile" "$quality" "$ray_tracing" "$frame_generation" "$test_name"; then
        log_to_file success "$logfile" "$test_name completed successfully"
        return 0
    else
        log_to_file error "$logfile" "$test_name failed"
        return 1
    fi
}

# Function to launch benchmark
run_bench() {
    local mode=$1                       # supported: proton
    local res=$2                        # resolution, e.g., 2560x1440
    local log=$3                        # log file path
    local quality_preset=${4:-high}     # quality preset: low, medium, high, ultra, custom
    local ray_tracing=${5:-off}         # ray tracing: off, on, psycho
    local frame_generation=${6:-off}    # frame generation: off, on, auto
    local test_name=${7:-""}            # test name for profile matching
    local default_result_name=""
    local original_benchmark_config_file="$BENCHMARK_CONFIG_FILE"
    local original_benchmark_results_filename="$BENCHMARK_RESULTS_FILENAME"
    local benchmark_started_epoch=0

    # Find game installation - check multiple possible locations
    local game_path="$STEAM_PATH/steamapps/common/Deus Ex Mankind Divided"
    if [[ ! -d "$game_path" ]]; then
        game_path="$STEAM_ROOT/steamapps/common/Deus Ex Mankind Divided"
        if [[ ! -d "$game_path" ]]; then
            game_path="$CUSTOM_LIBRARY_PATH/steamapps/common/Deus Ex Mankind Divided"
            if [[ ! -d "$game_path" ]]; then
                log_to_file error "$log" "Deus Ex Mankind Divided not found in any of these locations:"
                log_to_file error "$log" "  - $STEAM_PATH/steamapps/common/Deus Ex Mankind Divided"
                log_to_file error "$log" "  - $STEAM_ROOT/steamapps/common/Deus Ex Mankind Divided"
                log_to_file error "$log" "  - $CUSTOM_LIBRARY_PATH/steamapps/common/Deus Ex Mankind Divided"
                return 1
            fi
        fi
    fi

    local steam_library_path="${CUSTOM_LIBRARY_PATH}"
    if [[ "$game_path" == */steamapps/common/* ]]; then
        steam_library_path="${game_path%%/steamapps/common/*}"
    fi
    local steam_compat_data_path="${steam_library_path}/steamapps/compatdata/${GAME_ID}"
    export STEAM_COMPAT_DATA_PATH="$steam_compat_data_path"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"

    local requested_launch_mode="${DEUSEX_MD_LAUNCH_MODE:-proton}"
    local exe_path=""
    local game_cwd="$game_path"

    local proton_path=""
    proton_path="$STEAM_PATH/compatibilitytools.d/$PROTON_VERSION"
    if [[ ! -d "$proton_path" ]]; then
        proton_path="$STEAM_ROOT/compatibilitytools.d/$PROTON_VERSION"
        if [[ ! -d "$proton_path" ]]; then
            log_to_file error "$log" "Proton $PROTON_VERSION not found"
            return 1
        fi
    fi

    local -a proton_exe_candidates=(
        "$game_path/retail/DXMD.exe"
        "$game_path/DXMD.exe"
        "$game_path/bin/DXMD.exe"
    )
    local candidate_exe
    for candidate_exe in "${proton_exe_candidates[@]}"; do
        if [[ -f "$candidate_exe" ]]; then
            exe_path="$candidate_exe"
            break
        fi
    done

    if [[ -z "$exe_path" ]]; then
        log_to_file error "$log" "Game executable not found. Checked Proton candidates."
        for candidate_exe in "${proton_exe_candidates[@]}"; do
            log_to_file error "$log" "  - $candidate_exe"
        done
        return 1
    fi

    game_cwd="$(dirname "$exe_path")"

    log_to_file info "$log" "Requested launch mode: $requested_launch_mode"
    log_to_file info "$log" "Executable selected: $exe_path"
    log_to_file info "$log" "Launch mode: proton"

    log_to_file info "$log" "=== Running mode=$mode resolution=$res quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation ==="

    local -a launch_args
    local -a benchmark_args

    apply_setting "$mode" "$res" "$quality_preset" "$ray_tracing" "$frame_generation" "$log" launch_args "$test_name" || return 1

    read -r -a benchmark_args <<< "$BENCHMARK_ARGS_STRING"
    if [[ ${#benchmark_args[@]} -eq 0 ]]; then
        log_to_file error "$log" "Benchmark args are empty. Set BENCHMARK_ARGS or BENCHMARK_ARGS_STRING."
        return 1
    fi

    if [[ -z "$BENCHMARK_CONFIG_FILE" ]]; then
        BENCHMARK_CONFIG_FILE="$game_cwd/benchmark.ini"
    elif [[ "$BENCHMARK_CONFIG_FILE" != /* ]]; then
        BENCHMARK_CONFIG_FILE="$game_path/$BENCHMARK_CONFIG_FILE"
    fi

    default_result_name="dxmd_benchmark_${test_name:-manual-${mode}-${res}}_${SCRIPT_RUN_TIMESTAMP}.csv"
    if [[ -z "$BENCHMARK_RESULTS_FILENAME" ]]; then
        BENCHMARK_RESULTS_FILENAME="$default_result_name"
    fi

    prepare_benchmark_ini "$log"

    if ! command -v timeout >/dev/null 2>&1; then
        log_to_file error "$log" "Required command 'timeout' not found. Please install coreutils."
        restore_benchmark_ini "$log"
        BENCHMARK_CONFIG_FILE="$original_benchmark_config_file"
        BENCHMARK_RESULTS_FILENAME="$original_benchmark_results_filename"
        return 1
    fi

    if [[ "$TERMINATE_STALE_PROCESSES" -eq 1 ]]; then
        log_to_file info "$log" "Terminating stale DXMD/Proton processes before launch"
        kill_stale_processes
        sleep 1
    fi

    local -a full_launch_cmd
    local -a proton_run_cmd
    proton_run_cmd=("$proton_path/proton")

    if [[ "$ENABLE_GAMEMODERUN" -eq 1 ]]; then
        if command -v gamemoderun >/dev/null 2>&1; then
            proton_run_cmd=(gamemoderun "${proton_run_cmd[@]}")
        else
            log_to_file error "$log" "--gamemode requested but 'gamemoderun' was not found in PATH."
            restore_benchmark_ini "$log"
            BENCHMARK_CONFIG_FILE="$original_benchmark_config_file"
            BENCHMARK_RESULTS_FILENAME="$original_benchmark_results_filename"
            return 1
        fi
    fi

    full_launch_cmd=(
        timeout --foreground --signal=TERM --kill-after="${BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS}s" "${BENCHMARK_TIMEOUT_SECONDS}s"
        env
        "SteamAppId=${GAME_ID}"
        "SteamGameId=${GAME_ID}"
        "PROTON_VERB=${PROTON_VERB:-waitforexitandrun}"
        "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH"
        "STEAM_COMPAT_DATA_PATH=$steam_compat_data_path"
        "STEAM_RUNTIME=1"
        "PROTON_LOG=1"
        "VKD3D_FEATURE_LEVEL=12_2"
        "PROTON_HIDE_NVIDIA_GPU=0"
        "PROTON_ENABLE_NVAPI=1"
        "VKD3D_CONFIG=dxr12"
        "DXVK_ASYNC=1"
        "${proton_run_cmd[@]}" run
        "$exe_path"
        "${benchmark_args[@]}"
    )

    local full_launch_cmd_pretty=""
    printf -v full_launch_cmd_pretty '%q ' "${full_launch_cmd[@]}"
    log_to_file info "$log" "Full launch command: cd $(printf '%q' "$game_cwd") && ${full_launch_cmd_pretty% }"

    benchmark_started_epoch="$(date +%s)"
    log_to_file info "$log" "Benchmark start epoch: ${benchmark_started_epoch}"

    (
        cd "$game_cwd" || exit 1
        "${full_launch_cmd[@]}"
    ) >>"$log" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 124 || $exit_code -eq 137 ]]; then
        log_to_file warning "$log" "Benchmark timed out after ${BENCHMARK_TIMEOUT_SECONDS}s (mode=$mode)."
    fi

    if [[ "$RESULT_COPY_RETRY_SECONDS" -gt 0 ]]; then
        log_to_file info "$log" "Waiting ${RESULT_COPY_RETRY_SECONDS}s for benchmark result files to flush"
        sleep "$RESULT_COPY_RETRY_SECONDS"
    fi

    restore_benchmark_ini "$log"

    if [[ $exit_code -eq 0 ]]; then
        log_to_file success "$log" "Benchmark completed successfully for $mode"
    else
        log_to_file error "$log" "Benchmark failed for $mode (exit code: $exit_code)"
    fi

    if [[ -n "$test_name" ]]; then
        copy_benchmark_result_file "$test_name" "$log" "$game_path" "$game_cwd" "$benchmark_started_epoch"
    else
        copy_benchmark_result_file "manual-${mode}-${res}" "$log" "$game_path" "$game_cwd" "$benchmark_started_epoch"
    fi

    env \
        "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH" \
        "STEAM_COMPAT_DATA_PATH=$steam_compat_data_path" \
        "$proton_path/proton" run wineserver -k >>"$log" 2>&1 || true

    if [[ "$TERMINATE_STALE_PROCESSES" -eq 1 ]]; then
        kill_stale_processes
    fi

    BENCHMARK_CONFIG_FILE="$original_benchmark_config_file"
    BENCHMARK_RESULTS_FILENAME="$original_benchmark_results_filename"
    
    sleep 15   # give the game time to close cleanly
    return $exit_code
}

validate_runtime_settings() {
    normalize_seconds_var BENCHMARK_TIMEOUT_SECONDS
    normalize_seconds_var BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS
    normalize_positive_int_var BENCHMARK_CAPTURE_TIMEOUT_SECONDS
    normalize_positive_int_var RESULT_COPY_RETRY_SECONDS
    normalize_zero_one_var ENABLE_GAMEMODERUN
    normalize_zero_one_var TERMINATE_STALE_PROCESSES
    normalize_zero_one_var BENCHMARK_INI_ENABLED
    normalize_zero_one_var BENCHMARK_QUIT_WHEN_LOADED
    normalize_zero_one_var BENCHMARK_QUIT_AFTERWARDS
    normalize_zero_one_var BENCHMARK_RESULTS_TO_FILE
    normalize_zero_one_var BENCHMARK_SHOW_STATISTICS
    normalize_zero_one_var BENCHMARK_RESULTS_ADD_DXDIAG
    normalize_positive_int_var BENCHMARK_LOOP_COUNT
}

# Main function
main() {
    local run_all=false
    local tests_to_run=()
    local total_tests_count=0
    local cli_gamemode_override=false

    SCRIPT_RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    detect_gpu_metadata
    
    # Parse command line arguments
    while [[ $# -gt 0 ]]; do
        case $1 in
            --help|-h)
                show_help
                exit 0
                ;;
            --list)
                list_tests
                exit 0
                ;;
            --groups)
                list_groups
                exit 0
                ;;
            --validate-profiles)
                if validate_profiles; then
                    exit 0
                else
                    exit 1
                fi
                ;;
            --gamemode)
                ENABLE_GAMEMODERUN=1
                cli_gamemode_override=true
                shift
                ;;
            --native)
                log_error "Native mode is not supported for Deus Ex MD benchmark runner. Use Proton mode."
                exit 1
                ;;
            --proton)
                DEUSEX_MD_LAUNCH_MODE="proton"
                shift
                ;;
            --group)
                if [[ -z "$2" ]]; then
                    log_error "--group requires a group name"
                    exit 1
                fi
                if [[ "$2" == *,* ]]; then
                    log_error "Comma-separated groups are not supported. Use repeated flags: --group group1 --group group2"
                    exit 1
                fi
                if [[ ! "${TEST_GROUPS[$2]+isset}" ]]; then
                    log_error "Unknown test group '$2'. Use --groups to see available groups."
                    exit 1
                fi
                # Add all tests from the group
                read -ra group_tests <<< "${TEST_GROUPS[$2]}"
                tests_to_run+=("${group_tests[@]}")
                shift 2
                ;;
            --timeout-minutes)
                if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ || "$2" -le 0 ]]; then
                    log_error "--timeout-minutes requires a positive integer value"
                    exit 1
                fi
                BENCHMARK_TIMEOUT_MINUTES="$2"
                BENCHMARK_TIMEOUT_SECONDS=$((BENCHMARK_TIMEOUT_MINUTES * 60))
                shift 2
                ;;
            --benchmark-args)
                if [[ -z "${2:-}" ]]; then
                    log_error "--benchmark-args requires a value"
                    exit 1
                fi
                BENCHMARK_ARGS_STRING="$2"
                shift 2
                ;;
            --no-benchmark-ini)
                BENCHMARK_INI_ENABLED=0
                shift
                ;;
            --no-kill-stale)
                TERMINATE_STALE_PROCESSES=0
                shift
                ;;
            --all)
                run_all=true
                shift
                ;;
            -*)
                log_error "Unknown option $1"
                log_error "Use --help for usage information."
                exit 1
                ;;
            *)
                tests_to_run+=("$1")
                shift
                ;;
        esac
    done

    validate_runtime_settings
    
    # Check if Steam directory exists
    if [[ ! -d "$STEAM_PATH" ]]; then
        log_error "Steam directory not found at $STEAM_PATH"
        exit 1
    fi
    
    # Ensure log directory exists
    mkdir -p "${SCRIPT_DIR}/logs"

    # Create log file
    local logfile="${SCRIPT_DIR}/logs/deusex_md_benchmark_${SCRIPT_RUN_TIMESTAMP}.txt"
    echo "Deus Ex Mankind Divided Upscaling Benchmark – $(date)" >"$logfile"
    echo "Steam Path: $STEAM_PATH" >>"$logfile"
    echo "Proton Version: $PROTON_VERSION" >>"$logfile"
    echo "Launch Mode (requested): $DEUSEX_MD_LAUNCH_MODE" >>"$logfile"
    echo "GPU Metadata: $GPU_METADATA_TAG" >>"$logfile"
    echo "Per-test timeout: ${BENCHMARK_TIMEOUT_MINUTES} minute(s) (${BENCHMARK_TIMEOUT_SECONDS}s)" >>"$logfile"
    if [[ "$ENABLE_GAMEMODERUN" -eq 1 ]]; then
        if [[ "$cli_gamemode_override" == "true" ]]; then
            echo "GameMode: enabled (CLI)" >>"$logfile"
        else
            echo "GameMode: enabled (script variable)" >>"$logfile"
        fi
    else
        echo "GameMode: disabled" >>"$logfile"
    fi
    echo "=======================================" >>"$logfile"
    
    # Determine which tests to run
    if [[ "$run_all" == "true" ]]; then
        tests_to_run=()
        for test_name in "${!TESTS[@]}"; do
            tests_to_run+=("$test_name")
        done
        # Sort tests for consistent order
        IFS=$'\n' tests_to_run=($(sort <<<"${tests_to_run[*]}"))
        unset IFS
        log_to_file info "$logfile" "Running all available tests..."
    elif [[ ${#tests_to_run[@]} -eq 0 ]]; then
        # Default test if none specified (Proton-only)
        local default_test_name="proton-1080p-low"
        if [[ -z "${TESTS[$default_test_name]+isset}" ]]; then
            default_test_name=""
            for test_name in "${!TESTS[@]}"; do
                if [[ "$test_name" == proton-* ]]; then
                    default_test_name="$test_name"
                    break
                fi
            done
        fi
        if [[ -z "$default_test_name" ]]; then
            log_error "No proton tests are defined. Check benchmark/config/tests*.conf.sh"
            exit 1
        fi
        tests_to_run=("$default_test_name")
        log_to_file info "$logfile" "No tests specified, running default test: $default_test_name"
    fi

    total_tests_count=${#tests_to_run[@]}
    
    log_to_file info "$logfile" "Tests to run: ${tests_to_run[*]}"
    log_to_file info "$logfile" "Results will be saved to: $logfile"
    
    # Run the selected tests
    local failed_tests=()
    local successful_tests=()
    local current_test_index=0
    
    for test_name in "${tests_to_run[@]}"; do
        current_test_index=$((current_test_index + 1))
        log_to_file info "$logfile" "======================================="
        if run_test "$test_name" "$logfile" "$current_test_index" "$total_tests_count"; then
            successful_tests+=("$test_name")
        else
            failed_tests+=("$test_name")
        fi
    done
    
    # Summary
    log_to_file info "$logfile" "======================================="
    log_to_file info "$logfile" "Benchmark Summary:"
    log_to_file info "$logfile" "Total tests run: ${total_tests_count}"
    log_to_file info "$logfile" "Successful: ${#successful_tests[@]}"
    log_to_file info "$logfile" "Failed: ${#failed_tests[@]}"
    
    if [[ ${#successful_tests[@]} -gt 0 ]]; then
        log_to_file success "$logfile" "Successful tests:"
        for test in "${successful_tests[@]}"; do
            log_to_file success "$logfile" "  - $test"
        done
    fi
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_to_file error "$logfile" "Failed tests:"
        for test in "${failed_tests[@]}"; do
            log_to_file error "$logfile" "  - $test"
        done
    fi
    
    log_to_file info "$logfile" "Log file saved to: $logfile"
    log_to_file info "$logfile" "Logs directory: ${SCRIPT_DIR}/logs"
    log_to_file info "$logfile" "Benchmark result files saved to: ${BENCHMARK_RESULTS_OUTPUT_DIR}"
    log_to_file info "$logfile" "You can view the log with: cat \"$logfile\""
    
    # Exit with error code if any tests failed
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        exit 1
    fi
}

# Call main function with all arguments
main "$@"