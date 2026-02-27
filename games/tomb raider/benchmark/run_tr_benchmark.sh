#!/usr/bin/env bash
# ---------------------------------------------------
# Tomb Raider DLSS/FSR Benchmark on Ubuntu (Steam)
# ---------------------------------------------------
SYSTEM_NAME_DEFAULT="$(hostname -s 2>/dev/null || echo "default")"
SYSTEM_NAME_DEFAULT="${SYSTEM_NAME_DEFAULT,,}"
SYSTEM_NAME_DEFAULT="$(printf '%s' "$SYSTEM_NAME_DEFAULT" | sed -E 's/pavel//g; s/dolpa//g; s/[-_.]+/-/g; s/^-+|-+$//g')"
if [[ -z "$SYSTEM_NAME_DEFAULT" ]]; then
    SYSTEM_NAME_DEFAULT="default"
fi
SYSTEM_NAME="${TR_SYSTEM_NAME:-${SYSTEM_NAME:-$SYSTEM_NAME_DEFAULT}}"
SYSTEM_NAME="${SYSTEM_NAME// /_}"


SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

SYSTEM_CONFIG_DIR="${PROJECT_ROOT_DIR}/system"
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${SYSTEM_NAME}.conf.sh"
SYSTEM_CONFIG_OVERRIDE_FILE="${TR_BENCHMARK_CONFIG:-}"

# Built-in defaults (can be overridden by config files below)
GAME_ID=1091500
STEAM_PATH="${HOME}/.local/share/Steam"
STEAM_ROOT="${HOME}/.steam/root"
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"
ENABLE_MANGOHUD=1
ENABLE_GAMEMODERUN=0
PROTON_VERSION="GE-Proton10-25"
BENCHMARK_TIMEOUT_MINUTES=15
BENCHMARK_TIMEOUT_SECONDS=""
BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS=30
USER_SETTINGS_FOLDER=""
BENCHMARK_RESULTS_SOURCE_DIR=""
BENCHMARK_RESULTS_OUTPUT_DIR="${SCRIPT_DIR}/results"

if [[ -f "$SYSTEM_CONFIG_LOCAL_FILE" ]]; then
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_LOCAL_FILE"
fi

if [[ -n "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
    if [[ ! -f "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
        echo "Error: TR_BENCHMARK_CONFIG file not found: $SYSTEM_CONFIG_OVERRIDE_FILE" >&2
        exit 1
    fi
    # shellcheck source=/dev/null
    source "$SYSTEM_CONFIG_OVERRIDE_FILE"
fi

if [[ -z "${BENCHMARK_TIMEOUT_SECONDS:-}" ]]; then
    BENCHMARK_TIMEOUT_SECONDS=$((BENCHMARK_TIMEOUT_MINUTES * 60))
fi

if [[ -z "${USER_SETTINGS_FOLDER:-}" ]]; then
    USER_SETTINGS_FOLDER="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/AppData/Local/Crystal Dynamics/Tomb Raider"
fi

if [[ -z "${BENCHMARK_RESULTS_SOURCE_DIR:-}" ]]; then
    BENCHMARK_RESULTS_SOURCE_DIR="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Crystal Dynamics/Tomb Raider/benchmarkResults/"
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
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    log_error "Tests config file not found: $TESTS_CONFIG_FILE"
    exit 1
fi
# shellcheck source=/dev/null
source "$TESTS_CONFIG_FILE"

# Auto-add Frame Generation test variants for all base tests that have matching FG profiles.
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
        fg_profile_file="${SCRIPT_DIR}/profiles/UserSettings.${fg_test_name}.json"

        if [[ -f "$fg_profile_file" && ! "${TESTS[$fg_test_name]+isset}" ]]; then
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

TEST_GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.conf.sh"
if [[ ! -f "$TEST_GROUPS_CONFIG_FILE" ]]; then
    log_error "Test groups config file not found: $TEST_GROUPS_CONFIG_FILE"
    exit 1
fi
# shellcheck source=/dev/null
source "$TEST_GROUPS_CONFIG_FILE"

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
build_quick_resolution_variant_groups
build_dynamic_groups

# Function to show help
show_help() {
    echo "Tomb Raider Benchmark Script"
    echo "Usage: $0 [OPTIONS] [TEST_NAME...]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h          Show this help message"
    echo "  --all              Run all available tests"
    echo "  --list             List all available test names"
    echo "  --groups           List predefined test groups"
    echo "  --group GROUP      Run a predefined test group"
    echo "  --timeout-minutes  MIN  Per-test timeout in minutes (default: 15)"
    echo "  --gamemode         Run game launch through gamemoderun"
    echo "  --validate-profiles Check whether profile files exist for tests"
    echo ""
    echo "SYSTEM CONFIG FILES (loaded in order):"
    echo "  1) ${SYSTEM_CONFIG_LOCAL_FILE} (optional, selected by SYSTEM_NAME=${SYSTEM_NAME})"
    echo "  2) CP2077_BENCHMARK_CONFIG=/path/to/file.conf.sh (optional override)"
    echo ""
    echo "System selection override:"
    echo "  CP2077_SYSTEM_NAME=MY_MACHINE $0 --group quick-4k"
    echo ""
    echo "TESTS:"
    echo "  If no test names are specified, runs default test (native-1080p-low-rt-off)"
    echo "  Multiple test names can be specified to run them sequentially"
    echo ""
    echo "TEST GROUPS:"
    for group_name in "${!TEST_GROUPS[@]}"; do
        echo "  $group_name: ${TEST_GROUPS[$group_name]}"
    done | sort
    echo ""
    echo "Available tests:"
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
    echo "  $0 --group quick-4k"
    echo "  $0 --group 4k-quick-low"
    echo "  $0 --group 4k-quick-medium"
    echo "  $0 --group 4k-quick-high"
    echo "  $0 --group 4k-quick-ultra"
    echo "  $0 --group 1080p-quick-low"
    echo "  $0 --group 1080p-quick-medium"
    echo "  $0 --group 1080p-quick-high"
    echo "  $0 --group 1080p-quick-ultra"
    echo "  $0 --group 1440p-quick-low"
    echo "  $0 --group 1440p-quick-medium"
    echo "  $0 --group 1440p-quick-high"
    echo "  $0 --group 1440p-quick-ultra"
    echo "  $0 --group dlss-comparison"
    echo "  $0 --gamemode --group quick"
    echo "  $0 native-1080p-high-rt-off"
    echo "  $0 dlss-quality-1440p-high-rt-on"
    echo "  $0 fsr3-quality-4k-high-rt-off-fg-dlss"
    echo "  $0 native-1440p-ultra-rt-on dlss3-quality-1440p-high-rt-on-fg-frs31"
    echo ""
    echo "PROFILE FILES:"
    echo "  Each test expects a profile file in profiles/ directory named:"
    echo "  UserSettings.{TEST_NAME}.json"
    echo "  Example: UserSettings.fsr3-quality-4k-high-rt-off-fg-dlss.json"
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
        local profile_file="${SCRIPT_DIR}/profiles/UserSettings.${test_name}.json"
        if [[ ! -f "$profile_file" ]]; then
            log_warning "Missing: UserSettings.${test_name}.json"
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
    local source_dir="$BENCHMARK_RESULTS_SOURCE_DIR"
    local output_dir="$BENCHMARK_RESULTS_OUTPUT_DIR"

    mkdir -p "$output_dir"

    if [[ -z "$SCRIPT_RUN_TIMESTAMP" ]]; then
        SCRIPT_RUN_TIMESTAMP="$(date +%Y%m%d_%H%M%S)"
    fi

    if [[ ! -d "$source_dir" ]]; then
        log_to_file warning "$log" "Benchmark source directory not found: $source_dir"
        return 0
    fi

    local latest_benchmark_dir
    latest_benchmark_dir="$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -name "benchmark_*" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)"

    if [[ -z "$latest_benchmark_dir" || ! -d "$latest_benchmark_dir" ]]; then
        log_to_file warning "$log" "No benchmark_* directory found in $source_dir"
        return 0
    fi

    local source_file="$latest_benchmark_dir/summary.json"
    if [[ ! -f "$source_file" ]]; then
        log_to_file warning "$log" "summary.json not found in latest benchmark directory: $latest_benchmark_dir"
        return 0
    fi

    local destination_file="$output_dir/${GAME_ID}_result_${test_name}_${GPU_METADATA_TAG}_${SCRIPT_RUN_TIMESTAMP}.json"
    cp "$source_file" "$destination_file"
    if [[ $? -eq 0 ]]; then
        log_to_file success "$log" "Copied benchmark result: $destination_file"
    else
        log_to_file warning "$log" "Failed to copy benchmark result from $source_file"
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
    local settings_dir="$USER_SETTINGS_FOLDER"
    local profile_dir="${SCRIPT_DIR}/profiles"
    local target_settings_file="${settings_dir}/UserSettings.json"
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
    # Set launch arguments based on mode and resolution
    launch_args_ref=(--resolution "$resolution")

    if [[ ! -d "$profile_dir" ]]; then
        log_to_file error "$log" "Profiles directory does not exist: $profile_dir"
        return 1
    fi

    # Check if user settings directory exists
    if [[ ! -d "$settings_dir" ]]; then
        log_to_file error "$log" "User settings directory does not exist: $settings_dir"
        log_to_file warning "$log" "Please ensure the game has been run at least once to create the settings directory."
        return 1
    fi

    # Look for exact profile match based on test name or parameters
    local exact_profile=""
    
    if [[ -n "$test_name" ]]; then
        # Use test name for profile matching (preferred method)
        exact_profile="${profile_dir}/UserSettings.${test_name}.json"
    else
        # Fallback to parameter-based naming for backward compatibility
        exact_profile="${profile_dir}/UserSettings.${original_mode}.${quality_preset}.rt-${ray_tracing}.fg-${frame_generation}.json"
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
        if [[ -n "$test_name" ]]; then
            log_to_file error "$log" "Expected profile file: UserSettings.${test_name}.json"
        else
            log_to_file error "$log" "Available parameters: mode=$original_mode, quality=$quality_preset, ray_tracing=$ray_tracing, frame_generation=$frame_generation"
        fi
        log_to_file warning "$log" "Please ensure the exact profile file exists in $profile_dir"
        return 1
    fi

    # Verify that UserSettings.json exists after applying settings
    if [[ ! -f "$target_settings_file" ]]; then
        log_to_file error "$log" "UserSettings.json file does not exist at $target_settings_file"
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

# Function to launch with a specific upscaling mode
run_bench() {
    local mode=$1                       # e.g., dlss, fsr2
    local res=$2                        # resolution, e.g., 2560x1440
    local log=$3                        # log file path
    local quality_preset=${4:-high}     # quality preset: low, medium, high, ultra, custom
    local ray_tracing=${5:-off}         # ray tracing: off, on, psycho
    local frame_generation=${6:-off}    # frame generation: off, on, auto
    local test_name=${7:-""}            # test name for profile matching

    # Find Proton installation - check Steam root and custom library possible locations
    local proton_path="$STEAM_PATH/compatibilitytools.d/$PROTON_VERSION"
    if [[ ! -d "$proton_path" ]]; then
        proton_path="$STEAM_ROOT/compatibilitytools.d/$PROTON_VERSION"
        if [[ ! -d "$proton_path" ]]; then
            log_to_file error "$log" "Proton $PROTON_VERSION not found"
            return 1
        fi
    fi

    # Find game installation - check multiple possible locations
    local game_path="$STEAM_PATH/steamapps/common/Tomb Raider"
    if [[ ! -d "$game_path" ]]; then
        game_path="$STEAM_ROOT/steamapps/common/Tomb Raider"
        if [[ ! -d "$game_path" ]]; then
            game_path="$CUSTOM_LIBRARY_PATH/steamapps/common/Tomb Raider"
            if [[ ! -d "$game_path" ]]; then
                log_to_file error "$log" "Tomb Raider not found in any of these locations:"
                log_to_file error "$log" "  - $STEAM_PATH/steamapps/common/Tomb Raider"
                log_to_file error "$log" "  - $STEAM_ROOT/steamapps/common/Tomb Raider"
                log_to_file error "$log" "  - $CUSTOM_LIBRARY_PATH/steamapps/common/Tomb Raider"
                return 1
            fi
        fi
    fi

    local exe_path="$game_path/bin/x64/TombRaider.exe"
    if [[ ! -f "$exe_path" ]]; then
        log_to_file error "$log" "Game executable not found at $exe_path"
        return 1
    fi

    log_to_file info "$log" "=== Running mode=$mode resolution=$res quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation ==="
    
    # Set up environment
    export STEAM_COMPAT_DATA_PATH="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"

    local -a launch_args

    apply_setting "$mode" "$res" "$quality_preset" "$ray_tracing" "$frame_generation" "$log" launch_args "$test_name" || return 1

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

    # Launch the game with Proton
    if ! command -v timeout >/dev/null 2>&1; then
        log_to_file error "$log" "Required command 'timeout' not found. Please install coreutils."
        return 1
    fi

    timeout --foreground --signal=TERM --kill-after="${BENCHMARK_TIMEOUT_KILL_AFTER_SECONDS}s" "${BENCHMARK_TIMEOUT_SECONDS}s" \
        env \
        "SteamAppId=${GAME_ID}" \
        "SteamGameId=${GAME_ID}" \
        "PROTON_VERB=waitforexitandrun" \
        "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH" \
        "STEAM_COMPAT_DATA_PATH=$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
        "STEAM_RUNTIME=1" \
        "PROTON_LOG=1" \
        "VKD3D_FEATURE_LEVEL=12_0" \
        "${proton_run_cmd[@]}" run \
        "$exe_path" \
        --launcher-skip \
        --intro-skip \
        "${launch_args[@]}" \
        -benchmark \
        >>"$log" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 124 || $exit_code -eq 137 ]]; then
        log_to_file warning "$log" "Benchmark timed out after ${BENCHMARK_TIMEOUT_SECONDS}s (mode=$mode)."
    fi

    env \
        "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH" \
        "STEAM_COMPAT_DATA_PATH=$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
        "$proton_path/proton" run wineserver -k >>"$log" 2>&1 || true

    pkill -f "TombRaider.exe|TombRaiderLauncher.exe|CrashReporter" >/dev/null 2>&1 || true

    if [[ $exit_code -eq 0 ]]; then
        log_to_file success "$log" "Benchmark completed successfully for $mode"
    else
        log_to_file error "$log" "Benchmark failed for $mode (exit code: $exit_code)"
    fi

    if [[ -n "$test_name" ]]; then
        copy_benchmark_result_file "$test_name" "$log"
    else
        copy_benchmark_result_file "manual-${mode}-${res}" "$log"
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
    local logfile="${SCRIPT_DIR}/logs/tr_benchmark_${SCRIPT_RUN_TIMESTAMP}.txt"
    echo "Tomb Raider Upscaling Benchmark – $(date)" >"$logfile"
    echo "Steam Path: $STEAM_PATH" >>"$logfile"
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