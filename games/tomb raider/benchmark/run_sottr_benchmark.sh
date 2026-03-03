#!/usr/bin/env bash
# ---------------------------------------------------
# Shadow of the Tomb Raider DLSS/FSR Benchmark on Ubuntu (Steam)
# ---------------------------------------------------
SYSTEM_NAME_DEFAULT="$(hostname -s 2>/dev/null || echo "default")"
SYSTEM_NAME_DEFAULT="${SYSTEM_NAME_DEFAULT,,}"
SYSTEM_NAME_DEFAULT="$(printf '%s' "$SYSTEM_NAME_DEFAULT" | sed -E 's/pavel//g; s/dolpa//g; s/[-_.]+/-/g; s/^-+|-+$//g')"
if [[ -z "$SYSTEM_NAME_DEFAULT" ]]; then
    SYSTEM_NAME_DEFAULT="default"
fi
SYSTEM_NAME="${SOTTR_SYSTEM_NAME:-${SYSTEM_NAME:-$SYSTEM_NAME_DEFAULT}}"
SYSTEM_NAME="${SYSTEM_NAME// /_}"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

SYSTEM_CONFIG_DIR="${PROJECT_ROOT_DIR}/system"
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${SYSTEM_NAME}.conf.sh"
SYSTEM_CONFIG_OVERRIDE_FILE="${SOTTR_BENCHMARK_CONFIG:-}"
SOTTR_PROTON_VERSION_DEFAULT="GE-Proton9-27"
SOTTR_LAUNCH_MODE_DEFAULT="native"

# Built-in defaults (can be overridden by config files below)
GAME_ID=750920
STEAM_PATH="${HOME}/.local/share/Steam"
STEAM_ROOT="${HOME}/.steam/root"
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"
ENABLE_MANGOHUD=1
ENABLE_GAMEMODERUN=0
BENCHMARK_TIMEOUT_MINUTES=15
BENCHMARK_TIMEOUT_SECONDS=""
BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS=30
BENCHMARK_RESULTS_SOURCE_DIR=""
BENCHMARK_RESULTS_OUTPUT_DIR="${SCRIPT_DIR}/results"
NATIVE_PREFERENCES_FILE="${HOME}/.local/share/feral-interactive/Shadow of the Tomb Raider/preferences"
NATIVE_PREFERENCES_PROFILE_SUFFIX=".preferences.xml"
PROTON_PROFILE_FILE=""
PROTON_PREFERENCES_PROFILE_SUFFIX=".preferences.user.reg"
PROFILES_DIR="${SCRIPT_DIR}/profiles"

if [[ -f "$SYSTEM_CONFIG_LOCAL_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_LOCAL_FILE"
fi

if [[ -n "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
    if [[ ! -f "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
        echo "Error: SOTTR_BENCHMARK_CONFIG file not found: $SYSTEM_CONFIG_OVERRIDE_FILE" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_OVERRIDE_FILE"
fi

# Proton selection precedence:
# 1) SOTTR_PROTON_VERSION (game-specific override)
# 2) SOTTR_PROTON_VERSION_DEFAULT (game default)
# 3) PROTON_VERSION (shared system fallback)
PROTON_VERSION="${SOTTR_PROTON_VERSION:-${SOTTR_PROTON_VERSION_DEFAULT:-${PROTON_VERSION:-}}}"

# Launch mode selection precedence:
# 1) SOTTR_LAUNCH_MODE (game-specific override)
# 2) SOTTR_LAUNCH_MODE_DEFAULT (game default)
SOTTR_LAUNCH_MODE="${SOTTR_LAUNCH_MODE:-$SOTTR_LAUNCH_MODE_DEFAULT}"
SOTTR_LAUNCH_MODE="${SOTTR_LAUNCH_MODE,,}"

case "$SOTTR_LAUNCH_MODE" in
    native|proton)
        ;;
    *)
        echo "Error: invalid SOTTR_LAUNCH_MODE '$SOTTR_LAUNCH_MODE'. Supported values: native, proton" >&2
        exit 1
        ;;
esac

INITIAL_LAUNCH_MODE="$SOTTR_LAUNCH_MODE"
for cli_arg in "$@"; do
    case "$cli_arg" in
        --native)
            INITIAL_LAUNCH_MODE="native"
            ;;
        --proton)
            INITIAL_LAUNCH_MODE="proton"
            ;;
    esac
done

if [[ -z "${BENCHMARK_TIMEOUT_SECONDS:-}" ]]; then
    BENCHMARK_TIMEOUT_SECONDS=$((BENCHMARK_TIMEOUT_MINUTES * 60))
fi

if [[ -z "${BENCHMARK_RESULTS_SOURCE_DIR:-}" ]]; then
    local_native_results_dir="${HOME}/.local/share/feral-interactive/Shadow of the Tomb Raider/SaveData"
    local_proton_results_dir="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Shadow of the Tomb Raider/"
    local_proton_results_dir_alt="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/My Documents/Shadow of the Tomb Raider/"

    if [[ -d "$local_native_results_dir" ]]; then
        BENCHMARK_RESULTS_SOURCE_DIR="$local_native_results_dir"
    elif [[ -d "$local_proton_results_dir" ]]; then
        BENCHMARK_RESULTS_SOURCE_DIR="$local_proton_results_dir"
    elif [[ -d "$local_proton_results_dir_alt" ]]; then
        BENCHMARK_RESULTS_SOURCE_DIR="$local_proton_results_dir_alt"
    else
        BENCHMARK_RESULTS_SOURCE_DIR="$local_native_results_dir"
    fi
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

# Load base test definitions from external config
if [[ "$INITIAL_LAUNCH_MODE" == "proton" ]]; then
    TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.proton.conf.sh"
    if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
        TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/proton-test.conf.sh"
    fi
    if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
        TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/proton.tests.conf.sh"
    fi
else
    TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.native.conf.sh"
    if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
        TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
    fi
fi
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    log_error "Tests config file not found for launch mode '${INITIAL_LAUNCH_MODE}'."
    exit 1
fi
# shellcheck source=/dev/null
source "$TESTS_CONFIG_FILE"

# Auto-add Frame Generation test variants for all base tests that have matching native preferences profiles.
# Supported suffixes:
#   -fg-dlss  => DLSS frame generation profile
#   -fg-frs31 => AMD FSR 3.1 frame generation profile
# Legacy suffix kept for compatibility:
#   -fg
for base_test_name in "${!TESTS[@]}"; do
    if [[ "$base_test_name" == *-fg* ]]; then
        continue
    fi

    for fg_suffix in "fg-dlss" "fg-frs31" "fg"; do
        fg_test_name="${base_test_name}-${fg_suffix}"
        fg_preferences_file_sottr="${PROFILES_DIR}/${fg_test_name}${NATIVE_PREFERENCES_PROFILE_SUFFIX}"

        if [[ -f "$fg_preferences_file_sottr" && ! "${TESTS[$fg_test_name]+isset}" ]]; then
            read -r mode resolution quality ray_tracing frame_generation <<< "${TESTS[$base_test_name]}"
            case "$fg_suffix" in
                fg-dlss)
                    TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing fg-dlss"
                    ;;
                fg-frs31)
                    TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing fg-frs31"
                    ;;
                *)
                    TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing on"
                    ;;
            esac
        fi
    done
done

# Predefined test groups for common scenarios
declare -A TEST_GROUPS

if [[ "$INITIAL_LAUNCH_MODE" == "proton" ]]; then
    TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.proton.conf.sh"
    if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
        TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/proton-groups.conf.sh"
    fi
    if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
        TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/proton.groups.conf.sh"
    fi
else
    TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.native.conf.sh"
    if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
        TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.conf.sh"
    fi
fi
if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
    log_error "Test groups config file not found for launch mode '${INITIAL_LAUNCH_MODE}'."
    exit 1
fi
# shellcheck source=/dev/null
source "$TEST_GROUPS_CONFIG_FILE"

augment_existing_groups_with_fg_variants() {
    for group_name in "${!TEST_GROUPS[@]}"; do
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
                for fg_suffix in "fg-dlss" "fg-frs31" "fg"; do
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
build_dynamic_groups

# Function to show help
show_help() {
    echo "Shadow of the Tomb Raider Benchmark Script"
    echo "Usage: $0 [OPTIONS] [TEST_NAME...]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h          Show this help message"
    echo "  --all              Run all available tests"
    echo "  --list             List all available test names"
    echo "  --groups           List predefined test groups"
    echo "  --group GROUP      Run a predefined test group"
    echo "  --timeout-minutes  MIN  Per-test timeout in minutes (default: 15)"
    echo "  --native           Force native Linux launch mode (default)"
    echo "  --proton           Force Proton launch mode"
    echo "  --gamemode         Run game launch through gamemoderun"
    echo "  --validate-profiles Check whether profile files exist for tests"
    echo ""
    echo "SYSTEM CONFIG FILES (loaded in order):"
    echo "  1) ${SYSTEM_CONFIG_LOCAL_FILE} (optional, selected by SYSTEM_NAME=${SYSTEM_NAME})"
    echo "  2) SOTTR_BENCHMARK_CONFIG=/path/to/file.conf.sh (optional override)"
    echo ""
    echo "System selection override:"
    echo "  SOTTR_SYSTEM_NAME=MY_MACHINE $0 --group native-quick"
    echo ""
    echo "Launch mode override:"
    echo "  SOTTR_LAUNCH_MODE=native $0 --group native-quick"
    echo "  SOTTR_LAUNCH_MODE=proton $0 --group proton-quick"
    echo "  SOTTR_PROTON_VERSION=GE-Proton9-27 $0 --proton --group proton-quick"
    echo ""
    echo "TESTS:"
    echo "  If no test names are specified, runs default test (native-1080p-low-rt-off)"
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
        local dx12_mode_display="${params[5]:-on}"
        printf "  %-25s %s %s %s RT:%s FG:%s DX12:%s\n" "$test_name" "${params[0]}" "${params[1]}" "${params[2]}" "${params[3]}" "${params[4]}" "$dx12_mode_display"
    done | sort
    echo ""

    local proton_tests_config="${SCRIPT_DIR}/config/tests.proton.conf.sh"
    if [[ ! -f "$proton_tests_config" ]]; then
        proton_tests_config="${SCRIPT_DIR}/config/proton-test.conf.sh"
    fi
    if [[ ! -f "$proton_tests_config" ]]; then
        proton_tests_config="${SCRIPT_DIR}/config/proton.tests.conf.sh"
    fi

    local proton_groups_config="${SCRIPT_DIR}/config/groups.proton.conf.sh"
    if [[ ! -f "$proton_groups_config" ]]; then
        proton_groups_config="${SCRIPT_DIR}/config/proton-groups.conf.sh"
    fi
    if [[ ! -f "$proton_groups_config" ]]; then
        proton_groups_config="${SCRIPT_DIR}/config/proton.groups.conf.sh"
    fi

    if [[ "$INITIAL_LAUNCH_MODE" != "proton" && -f "$proton_tests_config" && -f "$proton_groups_config" ]]; then
        echo "Proton test groups (catalog):"
        (
            declare -A TEST_GROUPS=()
            # shellcheck source=/dev/null
            source "$proton_groups_config"
            for group_name in "${!TEST_GROUPS[@]}"; do
                echo "  $group_name: ${TEST_GROUPS[$group_name]}"
            done | sort
        )
        echo ""

        echo "Proton tests (catalog):"
        (
            declare -A TESTS=()
            # shellcheck source=/dev/null
            source "$proton_tests_config"
            for test_name in "${!TESTS[@]}"; do
                local params=(${TESTS[$test_name]})
                local dx12_mode_display="${params[5]:-on}"
                printf "  %-25s %s %s %s RT:%s FG:%s DX12:%s\n" "$test_name" "${params[0]}" "${params[1]}" "${params[2]}" "${params[3]}" "${params[4]}" "$dx12_mode_display"
            done | sort
        )
        echo ""
    fi

    echo ""
    echo "Examples:"
    echo "  $0 --help"
    echo "  $0 --list"
    echo "  $0 --groups"
    echo "  $0 --validate-profiles"
    echo "  $0 --all"
    echo "  $0 --native --group native-quick"
    echo "  $0 --proton --group proton-quick"
    echo "  $0 --group native-quick"
    echo "  $0 --group native-1080p-scaling"
    echo "  $0 --group native-1440p-scaling"
    echo "  $0 --group native-4k-scaling"
    echo "  $0 --group all-native"
    echo "  $0 --group all-proton"
    echo "  $0 --gamemode --group native-quick"
    echo "  $0 native-1080p-high-rt-off"
    echo "  $0 native-1440p-ultra-rt-off native-4k-high-rt-off"
    echo ""
    echo "PROFILE FILES:"
    echo "  Native launch mode:"
    echo "    profiles/{TEST_NAME}${NATIVE_PREFERENCES_PROFILE_SUFFIX}"
    echo "    Example: profiles/native-4k-high-rt-off${NATIVE_PREFERENCES_PROFILE_SUFFIX}"
    echo "  Proton launch mode:"
    echo "    profiles/{TEST_NAME}${PROTON_PREFERENCES_PROFILE_SUFFIX}"
    echo "    Example: profiles/proton-dx12-off-dlss-ultra-performance-4k-high${PROTON_PREFERENCES_PROFILE_SUFFIX}"
    echo ""
}

validate_profiles() {
    local missing_count=0
    local required_suffix="$NATIVE_PREFERENCES_PROFILE_SUFFIX"
    local profile_kind="native preferences"

    if [[ "$SOTTR_LAUNCH_MODE" == "proton" ]]; then
        required_suffix="$PROTON_PREFERENCES_PROFILE_SUFFIX"
        profile_kind="proton preferences"
    fi

    if [[ ! -d "$PROFILES_DIR" ]]; then
        log_error "Profiles directory not found: $PROFILES_DIR"
        return 1
    fi

    log_info "Validating profile files in $PROFILES_DIR ..."
    for test_name in "${!TESTS[@]}"; do
        local profile_file="${PROFILES_DIR}/${test_name}${required_suffix}"
        if [[ ! -f "$profile_file" ]]; then
            log_warning "Missing: ${test_name}${required_suffix}"
            missing_count=$((missing_count + 1))
        fi
    done

    if [[ $missing_count -eq 0 ]]; then
        log_success "Profile validation passed: all ${profile_kind} profiles exist."
        return 0
    fi

    log_error "Profile validation failed: ${missing_count} missing ${profile_kind} profile file(s)."
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
    local search_since_epoch="${3:-0}"
    local output_dir="$BENCHMARK_RESULTS_OUTPUT_DIR"
    local -a source_dir_candidates=(
        "$BENCHMARK_RESULTS_SOURCE_DIR"
        "${HOME}/.local/share/feral-interactive/Shadow of the Tomb Raider/SaveData"
        "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Shadow of the Tomb Raider/"
        "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/My Documents/Shadow of the Tomb Raider/"
        "${STEAM_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Shadow of the Tomb Raider/"
        "${STEAM_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/My Documents/Shadow of the Tomb Raider/"
    )

    mkdir -p "$output_dir"

    if [[ -z "$SCRIPT_RUN_TIMESTAMP" ]]; then
        SCRIPT_RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    fi

    local -a existing_source_dirs=()
    local candidate_dir
    for candidate_dir in "${source_dir_candidates[@]}"; do
        if [[ -n "$candidate_dir" && -d "$candidate_dir" ]]; then
            existing_source_dirs+=("$candidate_dir")
        fi
    done

    if [[ ${#existing_source_dirs[@]} -eq 0 ]]; then
        log_to_file warning "$log" "Benchmark source directory not found. Checked: ${source_dir_candidates[*]}"
        return 0
    fi

    local destination_file="$output_dir/${GAME_ID}_result_${test_name}_${GPU_METADATA_TAG}_${SCRIPT_RUN_TIMESTAMP}.json"

    local latest_summary_json=""
    latest_summary_json="$(
        for candidate_dir in "${existing_source_dirs[@]}"; do
            find "$candidate_dir" -type f -path '*/benchmark_*/summary.json' -printf '%T@ %p\n' 2>/dev/null
        done | awk -v since="$search_since_epoch" 'since <= 0 || $1 >= since' | sort -nr | head -n1 | cut -d' ' -f2-
    )"

    if [[ -z "$latest_summary_json" && "$search_since_epoch" -gt 0 ]]; then
        latest_summary_json="$(
            for candidate_dir in "${existing_source_dirs[@]}"; do
                find "$candidate_dir" -type f -path '*/benchmark_*/summary.json' -printf '%T@ %p\n' 2>/dev/null
            done | sort -nr | head -n1 | cut -d' ' -f2-
        )"
        if [[ -n "$latest_summary_json" ]]; then
            log_to_file warning "$log" "No fresh summary.json found since epoch ${search_since_epoch}; falling back to latest available file."
        fi
    fi

    if [[ -n "$latest_summary_json" && -f "$latest_summary_json" ]]; then
        if cp "$latest_summary_json" "$destination_file"; then
            log_to_file info "$log" "Using benchmark source file: $latest_summary_json"
            log_to_file success "$log" "Copied benchmark result: $destination_file"
            return 0
        fi
        log_to_file warning "$log" "Failed to copy benchmark result from $latest_summary_json"
        return 0
    fi

    local latest_native_txt=""
    latest_native_txt="$(
        for candidate_dir in "${existing_source_dirs[@]}"; do
            find "$candidate_dir" -maxdepth 1 -type f \( -name 'Shadow of the Tomb Raider_benchmarkresults_*.txt' -o -name 'SOTTR_*.txt' \) ! -name '*frametimes*' ! -name '*feral_*' -printf '%T@ %p\n' 2>/dev/null
        done | awk -v since="$search_since_epoch" 'since <= 0 || $1 >= since' | sort -nr | head -n1 | cut -d' ' -f2-
    )"

    if [[ -z "$latest_native_txt" && "$search_since_epoch" -gt 0 ]]; then
        latest_native_txt="$(
            for candidate_dir in "${existing_source_dirs[@]}"; do
                find "$candidate_dir" -maxdepth 1 -type f \( -name 'Shadow of the Tomb Raider_benchmarkresults_*.txt' -o -name 'SOTTR_*.txt' \) ! -name '*frametimes*' ! -name '*feral_*' -printf '%T@ %p\n' 2>/dev/null
            done | sort -nr | head -n1 | cut -d' ' -f2-
        )"
        if [[ -n "$latest_native_txt" ]]; then
            log_to_file warning "$log" "No fresh benchmark summary TXT found since epoch ${search_since_epoch}; falling back to latest available file."
        fi
    fi

    if [[ -z "$latest_native_txt" || ! -f "$latest_native_txt" ]]; then
        log_to_file warning "$log" "No benchmark summary artifact found (JSON or native TXT). Checked: ${existing_source_dirs[*]}"
        return 0
    fi

    local benchmark_text_stream
    if command -v strings >/dev/null 2>&1; then
        benchmark_text_stream="$(strings -a "$latest_native_txt")"
    else
        benchmark_text_stream="$(tr -cd '\11\12\15\40-\176' < "$latest_native_txt")"
    fi

    local min_fps max_fps avg_fps
    min_fps="$(printf '%s\n' "$benchmark_text_stream" | awk '/Average Benchmark Statistics/{in_average=1; next} in_average && /Min FPS:/{print $3; exit}')"
    max_fps="$(printf '%s\n' "$benchmark_text_stream" | awk '/Average Benchmark Statistics/{in_average=1; next} in_average && /Max FPS:/{print $3; exit}')"
    avg_fps="$(printf '%s\n' "$benchmark_text_stream" | awk '/Average Benchmark Statistics/{in_average=1; next} in_average && /Average FPS:/{print $3; exit}')"

    if [[ -z "$min_fps" || -z "$max_fps" || -z "$avg_fps" ]]; then
        min_fps="$(printf '%s\n' "$benchmark_text_stream" | awk '/Min FPS:/{print $3; exit}')"
        max_fps="$(printf '%s\n' "$benchmark_text_stream" | awk '/Max FPS:/{print $3; exit}')"
        avg_fps="$(printf '%s\n' "$benchmark_text_stream" | awk '/Average FPS:/{print $3; exit}')"
    fi

    if [[ -z "$min_fps" || -z "$max_fps" || -z "$avg_fps" ]]; then
        log_to_file warning "$log" "Failed to parse FPS values from native benchmark TXT: $latest_native_txt"
        return 0
    fi

    cat > "$destination_file" <<EOF
{
  "Data": {
    "minFps": $min_fps,
    "averageFps": $avg_fps,
    "maxFps": $max_fps
  },
  "Source": {
    "format": "native-benchmark-txt",
    "file": "$(basename "$latest_native_txt")"
  }
}
EOF

    if [[ $? -eq 0 ]]; then
        log_to_file info "$log" "Using native benchmark TXT source: $latest_native_txt"
        log_to_file success "$log" "Converted native benchmark TXT to JSON result: $destination_file"
    else
        log_to_file warning "$log" "Failed to write converted benchmark result JSON: $destination_file"
    fi
}

apply_native_preferences_profile() {
    local test_name="$1"
    local log="$2"
    local preferences_file="${NATIVE_PREFERENCES_FILE:-}"

    if [[ -z "$test_name" ]]; then
        log_to_file warning "$log" "No test name provided, skipping native preferences profile copy."
        return 0
    fi

    if [[ -z "$preferences_file" ]]; then
        log_to_file warning "$log" "NATIVE_PREFERENCES_FILE is not set; skipping native preferences profile copy."
        return 0
    fi

    local source_preferences_profile="${PROFILES_DIR}/${test_name}${NATIVE_PREFERENCES_PROFILE_SUFFIX}"
    if [[ ! -f "$source_preferences_profile" ]]; then
        log_to_file warning "$log" "Native preferences profile not found: $source_preferences_profile"
        return 0
    fi

    mkdir -p "$(dirname "$preferences_file")"
    if cp "$source_preferences_profile" "$preferences_file"; then
        log_to_file info "$log" "Copied native preferences profile: $source_preferences_profile -> $preferences_file"
    else
        log_to_file warning "$log" "Failed to copy native preferences profile: $source_preferences_profile"
    fi
}

resolve_proton_profile_file() {
    if [[ -n "${PROTON_PROFILE_FILE:-}" ]]; then
        if [[ -f "$PROTON_PROFILE_FILE" || -d "$(dirname "$PROTON_PROFILE_FILE")" ]]; then
            return 0
        fi
    fi

    local -a proton_profile_candidates=(
        "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/user.reg"
        "${STEAM_PATH}/steamapps/compatdata/${GAME_ID}/pfx/user.reg"
        "${STEAM_ROOT}/steamapps/compatdata/${GAME_ID}/pfx/user.reg"
    )

    local candidate_profile
    for candidate_profile in "${proton_profile_candidates[@]}"; do
        if [[ -f "$candidate_profile" ]]; then
            PROTON_PROFILE_FILE="$candidate_profile"
            return 0
        fi
    done

    for candidate_profile in "${proton_profile_candidates[@]}"; do
        if [[ -d "$(dirname "$candidate_profile")" ]]; then
            PROTON_PROFILE_FILE="$candidate_profile"
            return 0
        fi
    done

    return 1
}

apply_proton_preferences_profile() {
    local test_name="$1"
    local log="$2"

    if [[ -z "$test_name" ]]; then
        log_to_file warning "$log" "No test name provided, skipping Proton profile copy."
        return 0
    fi

    local source_proton_profile="${PROFILES_DIR}/${test_name}${PROTON_PREFERENCES_PROFILE_SUFFIX}"
    if [[ ! -f "$source_proton_profile" ]]; then
        log_to_file warning "$log" "Proton profile not found: $source_proton_profile"
        return 0
    fi

    if ! resolve_proton_profile_file; then
        log_to_file warning "$log" "Proton target user.reg not found under compatdata/${GAME_ID}/pfx; skipping Proton profile copy."
        return 0
    fi

    mkdir -p "$(dirname "$PROTON_PROFILE_FILE")"
    if cp "$source_proton_profile" "$PROTON_PROFILE_FILE"; then
        log_to_file info "$log" "Copied Proton profile: $source_proton_profile -> $PROTON_PROFILE_FILE"
    else
        log_to_file warning "$log" "Failed to copy Proton profile: $source_proton_profile"
    fi
}


# Function to apply settings based on mode and quality preset
# $1 - mode, e.g., native, dlss-quality, fsr2-quality, etc.
# $2 - resolution, e.g., 2560x1440
# $3 - quality preset, e.g., low, medium, high, ultra, custom
# $4 - ray tracing, e.g., off, on, psycho
# $5 - frame generation, e.g., off, on, auto
# $6 - log file, for logging errors and info
# $7 - output array name for launch args, passed by reference
# $8 - optional test name for profile matching (preferred method), if not provided will fallback to parameter-based naming
# $9 - optional effective launch mode (native|proton)
apply_setting() {
    local mode=$1
    local resolution=$2
    local quality_preset=$3
    local ray_tracing=$4
    local frame_generation=$5
    local log=$6
    local output_array_name=$7
    local test_name=${8:-""}
    local effective_launch_mode=${9:-${SOTTR_LAUNCH_MODE:-native}}
    local -n launch_args_ref="$output_array_name"

    local profile_suffix="$NATIVE_PREFERENCES_PROFILE_SUFFIX"
    local profile_kind="native preferences"
    if [[ "$effective_launch_mode" == "proton" ]]; then
        profile_suffix="$PROTON_PREFERENCES_PROFILE_SUFFIX"
        profile_kind="proton preferences"
    fi

    local original_mode="$mode"
    # Validate mode and extract base mode for profile matching
    case "$mode" in
        none)
            mode="native"
            original_mode="native"
            ;;
        native)
            ;;
        dlss-quality|dlss-balanced|dlss-performance|dlss-ultra-performance)
            # Keep original mode name for profile matching, extract base for validation
            ;;
        fsr2-quality|fsr2-balanced|fsr2-performance|fsr2-ultra-performance)
            # Keep original mode name for profile matching, extract base for validation
            ;;
        fsr21-quality|fsr21-balanced|fsr21-performance|fsr21-ultra-performance)
            # Keep original mode name for profile matching, extract base for validation
            ;;
        fsr3-quality|fsr3-balanced|fsr3-performance|fsr3-ultra-performance)
            # Keep original mode name for profile matching, extract base for validation
            ;;
        xess-quality|xess-balanced|xess-performance|xess-ultra-performance|xess)
            # Keep original mode name for profile matching, extract base for validation
            ;;
        *)
                log_to_file error "$log" "Unsupported mode '$mode'. Supported modes:"
                log_to_file error "$log" "  Native: native"
                log_to_file error "$log" "  DLSS: dlss-quality, dlss-balanced, dlss-performance, dlss-ultra-performance"
                log_to_file error "$log" "  FSR 2.0: fsr2-quality, fsr2-balanced, fsr2-performance, fsr2-ultra-performance"
                log_to_file error "$log" "  FSR 2.1: fsr21-quality, fsr21-balanced, fsr21-performance, fsr21-ultra-performance"
                log_to_file error "$log" "  FSR 3.0: fsr3-quality, fsr3-balanced, fsr3-performance, fsr3-ultra-performance"
                log_to_file error "$log" "  XeSS: xess-quality, xess-balanced, xess-performance, xess-ultra-performance"
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
        low|medium|high|ultra|custom)
            ;;
        *)
            log_to_file error "$log" "Unsupported quality preset '$quality_preset'. Supported: low, medium, high, ultra, custom"
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
        off|on|auto|x2|x4|fg-dlss|fg-frs31)
            ;;
        *)
            log_to_file error "$log" "Unsupported frame generation '$frame_generation'. Supported: off, on, auto, x2, x4, fg-dlss, fg-frs31"
            return 1
            ;;
    esac
    # Default launch arguments for Shadow of the Tomb Raider benchmark
    launch_args_ref=(--resolution "$resolution")

    # Log the applied settings for reference
    log_to_file info "$log" "Applied settings => mode=$original_mode resolution=$resolution quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation"
    if [[ -n "$test_name" ]]; then
        local expected_profile_file="${PROFILES_DIR}/${test_name}${profile_suffix}"
        log_to_file info "$log" "${profile_kind^} profile key: test name ($test_name)"
        log_to_file info "$log" "Expected ${profile_kind} profile: $expected_profile_file"
        if [[ ! -f "$expected_profile_file" ]]; then
            log_to_file warning "$log" "${profile_kind^} profile file is missing: $expected_profile_file"
        fi
    else
        log_to_file info "$log" "${profile_kind^} profile key: parameter-based"
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
    local directx12_mode="${params[5]:-on}"
    
    if [[ "$test_index" -gt 0 && "$total_tests" -gt 0 ]]; then
        log_to_file info "$logfile" "Running test ($test_index/$total_tests): $test_name"
    else
        log_to_file info "$logfile" "Running test: $test_name"
    fi
    log_to_file info "$logfile" "Parameters: mode=$mode resolution=$resolution quality=$quality ray_tracing=$ray_tracing frame_generation=$frame_generation directx12=$directx12_mode"
    # Apply settings and run benchmark
    if run_bench "$mode" "$resolution" "$logfile" "$quality" "$ray_tracing" "$frame_generation" "$test_name" "$directx12_mode"; then
        log_to_file success "$logfile" "$test_name completed successfully"
        return 0
    else
        log_to_file error "$logfile" "$test_name failed"
        return 1
    fi
}

# Function to launch with a specific upscaling mode
run_bench() {
    local mode=$1                       # e.g., dlss, fsr2
    local res=$2                        # resolution, e.g., 2560x1440
    local log=$3                        # log file path
    local quality_preset=${4:-high}     # quality preset: low, medium, high, ultra, custom
    local ray_tracing=${5:-off}         # ray tracing: off, on, psycho
    local frame_generation=${6:-off}    # frame generation: off, on, auto
    local test_name=${7:-""}            # test name for profile matching
    local directx12_mode=${8:-on}       # directx12 mode (proton): on|off
    local benchmark_started_epoch

    case "$directx12_mode" in
        on|off)
            ;;
        *)
            log_to_file error "$log" "Unsupported directx12 mode '$directx12_mode'. Supported: on, off"
            return 1
            ;;
    esac

    # Find game installation - check multiple possible locations (full + trial)
    local -a game_dir_candidates=(
        "$STEAM_PATH/steamapps/common/Shadow of the Tomb Raider"
        "$STEAM_PATH/steamapps/common/Shadow of the Tomb Raider Trial"
        "$STEAM_ROOT/steamapps/common/Shadow of the Tomb Raider"
        "$STEAM_ROOT/steamapps/common/Shadow of the Tomb Raider Trial"
        "$CUSTOM_LIBRARY_PATH/steamapps/common/Shadow of the Tomb Raider"
        "$CUSTOM_LIBRARY_PATH/steamapps/common/Shadow of the Tomb Raider Trial"
    )

    local game_path=""
    local candidate_dir
    for candidate_dir in "${game_dir_candidates[@]}"; do
        if [[ -d "$candidate_dir" ]]; then
            game_path="$candidate_dir"
            break
        fi
    done

    if [[ -z "$game_path" ]]; then
        log_to_file error "$log" "Shadow of the Tomb Raider not found in any known location:"
        for candidate_dir in "${game_dir_candidates[@]}"; do
            log_to_file error "$log" "  - $candidate_dir"
        done
        return 1
    fi

    local requested_launch_mode="${SOTTR_LAUNCH_MODE:-native}"
    local launch_mode="proton"
    local exe_path=""

    # Native mode behavior: prefer native Linux binary, then fallback to Proton.
    local -a native_exe_candidates=(
        "$game_path/ShadowOfTheTombRaider"
        "$game_path/ShadowOfTheTombRaider.x86_64"
        "$game_path/bin/ShadowOfTheTombRaider"
        "$game_path/bin/linux/ShadowOfTheTombRaider"
    )
    local candidate_exe
    if [[ "$requested_launch_mode" == "native" ]]; then
        for candidate_exe in "${native_exe_candidates[@]}"; do
            if [[ -x "$candidate_exe" ]]; then
                exe_path="$candidate_exe"
                launch_mode="native"
                break
            fi
        done
    fi

    local proton_path=""
    if [[ "$launch_mode" == "proton" ]]; then
        if [[ "$requested_launch_mode" == "native" ]]; then
            log_to_file warning "$log" "Native executable not found; falling back to Proton launch mode."
        fi

        # Find Proton installation - check Steam root and custom library possible locations
        proton_path="$STEAM_PATH/compatibilitytools.d/$PROTON_VERSION"
        if [[ ! -d "$proton_path" ]]; then
            proton_path="$STEAM_ROOT/compatibilitytools.d/$PROTON_VERSION"
            if [[ ! -d "$proton_path" ]]; then
                log_to_file error "$log" "Proton $PROTON_VERSION not found"
                return 1
            fi
        fi

        local -a proton_exe_candidates=()
        if [[ "$directx12_mode" == "off" ]]; then
            proton_exe_candidates=(
                "$game_path/bin/x64/SOTTR.exe"
                "$game_path/SOTTR.exe"
                "$game_path/bin/x64/SOTTR_DX12.exe"
                "$game_path/SOTTR_DX12.exe"
                "$game_path/bin/x64/ShadowOfTheTombRaider.exe"
                "$game_path/ShadowOfTheTombRaider.exe"
            )
        else
            proton_exe_candidates=(
                "$game_path/bin/x64/SOTTR_DX12.exe"
                "$game_path/SOTTR_DX12.exe"
                "$game_path/bin/x64/SOTTR.exe"
                "$game_path/SOTTR.exe"
                "$game_path/bin/x64/ShadowOfTheTombRaider.exe"
                "$game_path/ShadowOfTheTombRaider.exe"
            )
        fi

        for candidate_exe in "${proton_exe_candidates[@]}"; do
            if [[ -f "$candidate_exe" ]]; then
                exe_path="$candidate_exe"
                break
            fi
        done

        if [[ -z "$exe_path" ]]; then
            log_to_file error "$log" "Game executable not found. Checked native and Proton candidates."
            for candidate_exe in "${native_exe_candidates[@]}"; do
                log_to_file error "$log" "  - $candidate_exe"
            done
            for candidate_exe in "${proton_exe_candidates[@]}"; do
                log_to_file error "$log" "  - $candidate_exe"
            done
            return 1
        fi
    fi

    local -a direct_benchmark_args=(
        -nolauncher
        -benchmark
        -silent
        --non-interactive
    )

    log_to_file info "$log" "Requested launch mode: $requested_launch_mode"
    log_to_file info "$log" "Executable selected: $exe_path"
    log_to_file info "$log" "Launch mode: $launch_mode"

    log_to_file info "$log" "=== Running mode=$mode resolution=$res quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation directx12=$directx12_mode ==="
    
    local -a launch_args

    apply_setting "$mode" "$res" "$quality_preset" "$ray_tracing" "$frame_generation" "$log" launch_args "$test_name" "$launch_mode" || return 1
    if [[ "$launch_mode" == "native" ]]; then
        apply_native_preferences_profile "$test_name" "$log"
    else
        apply_proton_preferences_profile "$test_name" "$log"
    fi
    log_to_file info "$log" "Launch args: ${direct_benchmark_args[*]} ${launch_args[*]}"

    local -a full_launch_cmd
    if [[ "$launch_mode" == "native" ]]; then
        local -a native_run_cmd=()
        if [[ "$ENABLE_GAMEMODERUN" -eq 1 ]]; then
            if command -v gamemoderun >/dev/null 2>&1; then
                native_run_cmd=(gamemoderun)
            else
                log_to_file error "$log" "--gamemode requested but 'gamemoderun' was not found in PATH."
                return 1
            fi
        fi

        full_launch_cmd=(
            timeout --foreground --signal=TERM --kill-after="${BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS}s" "${BENCHMARK_TIMEOUT_SECONDS}s"
            env
            "SteamAppId=${GAME_ID}"
            "SteamGameId=${GAME_ID}"
            "${native_run_cmd[@]}"
            "$exe_path"
            "${direct_benchmark_args[@]}"
            "${launch_args[@]}"
        )
    else
        # Set up compatibility environment for Proton launches
        export STEAM_COMPAT_DATA_PATH="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID"
        export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"

        local -a proton_run_cmd
        proton_run_cmd=("$proton_path/proton")

        if [[ "$ENABLE_GAMEMODERUN" -eq 1 ]]; then
            if command -v gamemoderun >/dev/null 2>&1; then
                proton_run_cmd=(gamemoderun "${proton_run_cmd[@]}")
            else
                log_to_file error "$log" "--gamemode requested but 'gamemoderun' was not found in PATH."
                return 1
            fi
        fi

        full_launch_cmd=(
            timeout --foreground --signal=TERM --kill-after="${BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS}s" "${BENCHMARK_TIMEOUT_SECONDS}s"
            env
            "SteamAppId=${GAME_ID}"
            "SteamGameId=${GAME_ID}"
            "PROTON_VERB=waitforexitandrun"
            "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH"
            "STEAM_COMPAT_DATA_PATH=$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID"
            "STEAM_RUNTIME=1"
            "PROTON_LOG=1"
            "VKD3D_FEATURE_LEVEL=12_0"
            "${proton_run_cmd[@]}" run
            "$exe_path"
            "${direct_benchmark_args[@]}"
            "${launch_args[@]}"
        )
    fi

    local full_launch_cmd_pretty=""
    printf -v full_launch_cmd_pretty '%q ' "${full_launch_cmd[@]}"
    log_to_file info "$log" "Full launch command: cd $(printf '%q' "$game_path") && ${full_launch_cmd_pretty% }"

    # Launch the game with Proton
    if ! command -v timeout >/dev/null 2>&1; then
        log_to_file error "$log" "Required command 'timeout' not found. Please install coreutils."
        return 1
    fi

    benchmark_started_epoch="$(date +%s)"

    (
        cd "$game_path" || exit 1
        "${full_launch_cmd[@]}"
    ) >>"$log" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 124 || $exit_code -eq 137 ]]; then
        log_to_file warning "$log" "Benchmark timed out after ${BENCHMARK_TIMEOUT_SECONDS}s (mode=$mode)."
    fi

    if [[ "$launch_mode" == "proton" ]]; then
        env \
            "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH" \
            "STEAM_COMPAT_DATA_PATH=$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
            "$proton_path/proton" run wineserver -k >>"$log" 2>&1 || true

        pkill -f "SOTTR.exe|SOTTR_DX12.exe|TombRaider.exe|TombRaiderLauncher.exe|CrashReporter" >/dev/null 2>&1 || true
    fi

    if [[ $exit_code -eq 0 ]]; then
        log_to_file success "$log" "Benchmark completed successfully for $mode"
    else
        log_to_file error "$log" "Benchmark failed for $mode (exit code: $exit_code)"
    fi

    if [[ -n "$test_name" ]]; then
        copy_benchmark_result_file "$test_name" "$log" "$benchmark_started_epoch"
    else
        copy_benchmark_result_file "manual-${mode}-${res}" "$log" "$benchmark_started_epoch"
    fi
    
    sleep 15   # give the game time to close cleanly
    return $exit_code
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
            --group)
                if [[ -z "$2" ]]; then
                    log_error "--group requires a group name"
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
            --native)
                SOTTR_LAUNCH_MODE="native"
                shift
                ;;
            --proton)
                SOTTR_LAUNCH_MODE="proton"
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
    
    # Check if Steam directory exists
    if [[ ! -d "$STEAM_PATH" ]]; then
        log_error "Steam directory not found at $STEAM_PATH"
        exit 1
    fi
    
    # Ensure log directory exists
    mkdir -p "${SCRIPT_DIR}/logs"

    # Create log file
    local logfile="${SCRIPT_DIR}/logs/sottr_benchmark_${SCRIPT_RUN_TIMESTAMP}.txt"
    echo "Shadow of the Tomb Raider Upscaling Benchmark – $(date)" >"$logfile"
    echo "Steam Path: $STEAM_PATH" >>"$logfile"
    echo "Launch Mode (requested): $SOTTR_LAUNCH_MODE" >>"$logfile"
    echo "Proton Version: $PROTON_VERSION" >>"$logfile"
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
        # Default test if none specified
        tests_to_run=("native-1080p-low-rt-off")
        log_to_file info "$logfile" "No tests specified, running default test: native-1080p-low-rt-off"
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