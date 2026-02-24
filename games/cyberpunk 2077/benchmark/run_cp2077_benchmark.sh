#!/usr/bin/env bash
# ---------------------------------------------------
# Cyberpunk 2077 DLSS/FSR Benchmark on Ubuntu (Steam)
# ---------------------------------------------------
GAME_ID=1091500                                     # Steam AppID for Cyberpunk 2077
STEAM_PATH="${HOME}/.local/share/Steam"             # Main Steam installation
STEAM_ROOT="${HOME}/.steam/root"                    # Alternative Steam root path
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"         # Custom Steam library path
ENABLE_MANGOHUD=1
ENABLE_GAMEMODERUN=0                               # 0=disabled (default), 1=prepend gamemoderun to Proton launch
PROTON_VERSION="GE-Proton10-25"                      # Adjust version as needed

USER_SETTINGS_FOLDER="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/AppData/Local/CD Projekt Red/Cyberpunk 2077"  # User settings directory
BENCHMARK_RESULTS_SOURCE_DIR="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/CD Projekt Red/Cyberpunk 2077/benchmarkResults/" # Default folder where game writes benchmark result json files

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BENCHMARK_RESULTS_OUTPUT_DIR="${SCRIPT_DIR}/results"    # Folder where this script stores copied per-test results
SCRIPT_RUN_TIMESTAMP=""                                 # Set once in main and reused by all tests in the same run

# Define available test configurations
declare -A TESTS

# Load base test definitions from external config
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
    echo "Error: Tests config file not found: $TESTS_CONFIG_FILE" >&2
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
    echo "Error: Test groups config file not found: $TEST_GROUPS_CONFIG_FILE" >&2
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
    echo "Cyberpunk 2077 Benchmark Script"
    echo "Usage: $0 [OPTIONS] [TEST_NAME...]"
    echo ""
    echo "OPTIONS:"
    echo "  --help, -h          Show this help message"
    echo "  --all              Run all available tests"
    echo "  --list             List all available test names"
    echo "  --groups           List predefined test groups"
    echo "  --group GROUP      Run a predefined test group"
    echo "  --gamemode         Run game launch through gamemoderun"
    echo "  --validate-profiles Check whether profile files exist for tests"
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
        echo "Error: Profiles directory not found: ${SCRIPT_DIR}/profiles"
        return 1
    fi

    echo "Validating profile files in ${SCRIPT_DIR}/profiles ..."
    for test_name in "${!TESTS[@]}"; do
        local profile_file="${SCRIPT_DIR}/profiles/UserSettings.${test_name}.json"
        if [[ ! -f "$profile_file" ]]; then
            echo "Missing: UserSettings.${test_name}.json"
            missing_count=$((missing_count + 1))
        fi
    done

    if [[ $missing_count -eq 0 ]]; then
        echo "Profile validation passed: all test profiles exist."
        return 0
    fi

    echo "Profile validation failed: ${missing_count} missing profile file(s)."
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
        echo "Warning: Benchmark source directory not found: $source_dir" | tee -a "$log"
        return 0
    fi

    local latest_benchmark_dir
    latest_benchmark_dir="$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -name "benchmark_*" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)"

    if [[ -z "$latest_benchmark_dir" || ! -d "$latest_benchmark_dir" ]]; then
        echo "Warning: No benchmark_* directory found in $source_dir" | tee -a "$log"
        return 0
    fi

    local source_file="$latest_benchmark_dir/summary.json"
    if [[ ! -f "$source_file" ]]; then
        echo "Warning: summary.json not found in latest benchmark directory: $latest_benchmark_dir" | tee -a "$log"
        return 0
    fi

    local destination_file="$output_dir/${GAME_ID}_result_${test_name}_${SCRIPT_RUN_TIMESTAMP}.json"
    cp "$source_file" "$destination_file"
    if [[ $? -eq 0 ]]; then
        echo "Copied benchmark result: $destination_file" | tee -a "$log"
    else
        echo "Warning: Failed to copy benchmark result from $source_file" | tee -a "$log"
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
            echo "Error: Unsupported mode '$mode'. Supported modes:" | tee -a "$log"
            echo "  Native: native" | tee -a "$log"
            echo "  DLSS: dlss-quality, dlss-balanced, dlss-performance, dlss-ultra-performance" | tee -a "$log"
            echo "  FSR 2.0: fsr2-quality, fsr2-balanced, fsr2-performance, fsr2-ultra-performance" | tee -a "$log"
            echo "  FSR 2.1: fsr21-quality, fsr21-balanced, fsr21-performance, fsr21-ultra-performance" | tee -a "$log"
            echo "  FSR 3.0: fsr3-quality, fsr3-balanced, fsr3-performance, fsr3-ultra-performance" | tee -a "$log"
            echo "  XeSS: xess-quality, xess-balanced, xess-performance, xess-ultra-performance" | tee -a "$log"
            return 1
            ;;
    esac
    # Validate resolution format (e.g., 2560x1440)
    if [[ ! "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "Error: Invalid resolution '$resolution'. Expected WIDTHxHEIGHT (e.g., 2560x1440)." | tee -a "$log"
        return 1
    fi
    # Validate quality preset
    case "$quality_preset" in
        low|medium|high|ultra|custom)
            ;;
        *)
            echo "Error: Unsupported quality preset '$quality_preset'. Supported: low, medium, high, ultra, custom" | tee -a "$log"
            return 1
            ;;
    esac
    # Validate ray tracing options
    case "$ray_tracing" in
        off|on|psycho)
            ;;
        *)
            echo "Error: Unsupported ray tracing '$ray_tracing'. Supported: off, on, psycho" | tee -a "$log"
            return 1
            ;;
    esac
    # Validate frame generation options
    case "$frame_generation" in
        off|on|auto|x2|x4|fg-dlss|fg-frs31)
            ;;
        *)
            echo "Error: Unsupported frame generation '$frame_generation'. Supported: off, on, auto, x2, x4, fg-dlss, fg-frs31" | tee -a "$log"
            return 1
            ;;
    esac
    # Set launch arguments based on mode and resolution
    launch_args_ref=(--resolution "$resolution")

    if [[ ! -d "$profile_dir" ]]; then
        echo "Error: Profiles directory does not exist: $profile_dir" | tee -a "$log"
        return 1
    fi

    # Check if user settings directory exists
    if [[ ! -d "$settings_dir" ]]; then
        echo "Error: User settings directory does not exist: $settings_dir" | tee -a "$log"
        echo "Please ensure the game has been run at least once to create the settings directory." | tee -a "$log"
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
            echo "Applied settings profile: $exact_profile" | tee -a "$log"
        else
            echo "Error: Failed to copy settings profile to $target_settings_file" | tee -a "$log"
            return 1
        fi
    else
        echo "Error: Required settings profile not found: $exact_profile" | tee -a "$log"
        if [[ -n "$test_name" ]]; then
            echo "Expected profile file: UserSettings.${test_name}.json" | tee -a "$log"
        else
            echo "Available parameters: mode=$original_mode, quality=$quality_preset, ray_tracing=$ray_tracing, frame_generation=$frame_generation" | tee -a "$log"
        fi
        echo "Please ensure the exact profile file exists in $profile_dir" | tee -a "$log"
        return 1
    fi

    # Verify that UserSettings.json exists after applying settings
    if [[ ! -f "$target_settings_file" ]]; then
        echo "Error: UserSettings.json file does not exist at $target_settings_file" | tee -a "$log"
        echo "Please ensure a valid settings profile was applied or the game has been configured." | tee -a "$log"
        return 1
    fi
    # Log the applied settings for reference
    echo "Applied settings => mode=$original_mode resolution=$resolution quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation" | tee -a "$log"
    if [[ -n "$test_name" ]]; then
        echo "Profile selection method: test name ($test_name)" | tee -a "$log"
    else
        echo "Profile selection method: parameter-based" | tee -a "$log"
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
        echo "Error: Unknown test '$test_name'. Use --list to see available tests." >&2
        return 1
    fi
    
    local params=(${TESTS[$test_name]})
    local mode="${params[0]}"
    local resolution="${params[1]}"
    local quality="${params[2]}"
    local ray_tracing="${params[3]}"
    local frame_generation="${params[4]}"
    
    if [[ "$test_index" -gt 0 && "$total_tests" -gt 0 ]]; then
        echo "Running test ($test_index/$total_tests): $test_name"
    else
        echo "Running test: $test_name"
    fi
    echo "Parameters: mode=$mode resolution=$resolution quality=$quality ray_tracing=$ray_tracing frame_generation=$frame_generation"
    # Apply settings and run benchmark
    if run_bench "$mode" "$resolution" "$logfile" "$quality" "$ray_tracing" "$frame_generation" "$test_name"; then
        echo "✓ $test_name completed successfully"
        return 0
    else
        echo "✗ $test_name failed"
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
            echo "Error: Proton $PROTON_VERSION not found" | tee -a "$log"
            return 1
        fi
    fi

    # Find game installation - check multiple possible locations
    local game_path="$STEAM_PATH/steamapps/common/Cyberpunk 2077"
    if [[ ! -d "$game_path" ]]; then
        game_path="$STEAM_ROOT/steamapps/common/Cyberpunk 2077"
        if [[ ! -d "$game_path" ]]; then
            game_path="$CUSTOM_LIBRARY_PATH/steamapps/common/Cyberpunk 2077"
            if [[ ! -d "$game_path" ]]; then
                echo "Error: Cyberpunk 2077 not found in any of these locations:" | tee -a "$log"
                echo "  - $STEAM_PATH/steamapps/common/Cyberpunk 2077" | tee -a "$log"
                echo "  - $STEAM_ROOT/steamapps/common/Cyberpunk 2077" | tee -a "$log"
                echo "  - $CUSTOM_LIBRARY_PATH/steamapps/common/Cyberpunk 2077" | tee -a "$log"
                return 1
            fi
        fi
    fi

    local exe_path="$game_path/bin/x64/Cyberpunk2077.exe"
    if [[ ! -f "$exe_path" ]]; then
        echo "Error: Game executable not found at $exe_path" | tee -a "$log"
        return 1
    fi

    echo "=== Running mode=$mode resolution=$res quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation ===" | tee -a "$log"
    
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
            echo "Error: --gamemode requested but 'gamemoderun' was not found in PATH." | tee -a "$log"
            return 1
        fi
    fi

    # Launch the game with Proton
    SteamAppId=${GAME_ID} \
    SteamGameId=${GAME_ID} \
    PROTON_VERB="waitforexitandrun" \
    STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH" \
    STEAM_COMPAT_DATA_PATH="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
    STEAM_RUNTIME=1 \
    PROTON_LOG=1 \
    VKD3D_FEATURE_LEVEL=12_0 \
    "${proton_run_cmd[@]}" run \
    "$exe_path" \
        --launcher-skip \
        --intro-skip \
        "${launch_args[@]}" \
        -benchmark
            >>"$log" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 124 || $exit_code -eq 137 ]]; then
        echo "Benchmark timed out after ${BENCHMARK_TIMEOUT_SECONDS}s (mode=$mode)." | tee -a "$log"
    fi

    env \
        "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH" \
        "STEAM_COMPAT_DATA_PATH=$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
        "$proton_path/proton" run wineserver -k >>"$log" 2>&1 || true

    pkill -f "Cyberpunk2077.exe|REDprelauncher.exe|CrashReporter" >/dev/null 2>&1 || true

    if [[ $exit_code -eq 0 ]]; then
        echo "Benchmark completed successfully for $mode" | tee -a "$log"
    else
        echo "Benchmark failed for $mode (exit code: $exit_code)" | tee -a "$log"
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
                    echo "Error: --group requires a group name" >&2
                    exit 1
                fi
                if [[ ! "${TEST_GROUPS[$2]+isset}" ]]; then
                    echo "Error: Unknown test group '$2'. Use --groups to see available groups." >&2
                    exit 1
                fi
                # Add all tests from the group
                read -ra group_tests <<< "${TEST_GROUPS[$2]}"
                tests_to_run+=("${group_tests[@]}")
                shift 2
                ;;
            --all)
                run_all=true
                shift
                ;;
            -*)
                echo "Error: Unknown option $1" >&2
                echo "Use --help for usage information." >&2
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
        echo "Error: Steam directory not found at $STEAM_PATH"
        exit 1
    fi
    
    # Ensure log directory exists
    mkdir -p "${SCRIPT_DIR}/logs"

    # Create log file
    local logfile="${SCRIPT_DIR}/logs/cyberpunk_benchmark_${SCRIPT_RUN_TIMESTAMP}.txt"
    echo "Cyberpunk 2077 Upscaling Benchmark – $(date)" >"$logfile"
    echo "Steam Path: $STEAM_PATH" >>"$logfile"
    echo "Proton Version: $PROTON_VERSION" >>"$logfile"
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
        echo "Running all available tests..."
    elif [[ ${#tests_to_run[@]} -eq 0 ]]; then
        # Default test if none specified
        tests_to_run=("native-1080p-low-rt-off")
        echo "No tests specified, running default test: native-1080p-low-rt-off"
    fi

    total_tests_count=${#tests_to_run[@]}
    
    echo "Tests to run: ${tests_to_run[*]}"
    echo "Results will be saved to: $logfile"
    echo ""
    
    # Run the selected tests
    local failed_tests=()
    local successful_tests=()
    local current_test_index=0
    
    for test_name in "${tests_to_run[@]}"; do
        current_test_index=$((current_test_index + 1))
        echo "======================================="
        if run_test "$test_name" "$logfile" "$current_test_index" "$total_tests_count"; then
            successful_tests+=("$test_name")
        else
            failed_tests+=("$test_name")
        fi
        echo ""
    done
    
    # Summary
    echo "======================================="
    echo "Benchmark Summary:"
    echo "Total tests run: ${total_tests_count}"
    echo "Successful: ${#successful_tests[@]}"
    echo "Failed: ${#failed_tests[@]}"
    echo ""
    
    if [[ ${#successful_tests[@]} -gt 0 ]]; then
        echo "✓ Successful tests:"
        for test in "${successful_tests[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi
    
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        echo "✗ Failed tests:"
        for test in "${failed_tests[@]}"; do
            echo "  - $test"
        done
        echo ""
    fi
    
    echo "Log file saved to: $logfile"
    echo "Logs directory: ${SCRIPT_DIR}/logs"
    echo "Benchmark result files saved to: ${BENCHMARK_RESULTS_OUTPUT_DIR}"
    echo "You can view the log with: cat \"$logfile\""
    
    # Exit with error code if any tests failed
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        exit 1
    fi
}

# Call main function with all arguments
main "$@"