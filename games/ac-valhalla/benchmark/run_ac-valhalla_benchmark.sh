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
SYSTEM_NAME_DEFAULT=${SYSTEM_NAME:-"default"}                                         # default system name (can be overridden by the local config); if empty, it will be derived from the hostname
GAME_SHORT_NAME="ac-valhalla"                                   # short name for the game (used for folder names, logs, …); should be lowercase and contain only letters, numbers and dashes/underscores
DEFAULT_TEST_TO_RUN="native-1080p-low-rt-off"   # default test to run if no tests are specified via command‑line arguments; should be one of the keys in the TESTS array defined in config/tests.conf.sh (e.g. "native-1080p-low-rt-off")

STEAM_PATH="${HOME}/.local/share/Steam"     # Base path to Steam (used for Proton, compatdata, …)
STEAM_ROOT="${HOME}/.steam/root"            # Steam root path
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam" # Custom Steam library path (where the game is installed) – override in config if needed


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
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${SYSTEM_NAME}.conf.sh"
GAME_BENCHMARK_CONFIG_DEFAULT="${SCRIPT_DIR}/config/game.${GAME_SHORT_NAME}.conf.sh"  # default game‑specific config (can be overridden by the environment variable GAME_BENCHMARK_CONFIG)
SYSTEM_CONFIG_OVERRIDE_FILE="${GAME_BENCHMARK_CONFIG:-}"   # <- env‑var

# --------------------------------------------------------------------
#  Default values (can be overridden by the config files below)
# --------------------------------------------------------------------
ENABLE_PROTON=1                             # Run the game in Proton mode (if 1); if 0, run in native Linux mode; can be overridden by --proton / --native
PROTON_VERSION_DEFAULT="GE-Proton10-32"     # default Proton version to use for the script (can be overridden by the system default config or the environment variable GAME_PROTON_VERSION)

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

SCRIPT_RUN_TIMESTAMP=""

# Predefined test groups and tests for common scenarios
declare -A TEST_GROUPS
declare -A TESTS
declare -a BENCHMARK_HELPER_PIDS

# Screenshot Variables
_NUMBER_OF_SCREENSHOTS=1                     # Number of screenshots to take during the benchmark run (if NEED_TO_TAKE_SCREENSHOT_OF_RESULTS is true)

# --------------------------------------------------------------------
#  Load the shared bash‑utils library (provides logging helpers, Bash utilities, …)
# --------------------------------------------------------------------
BASH_UTILS_LOADER="${SCRIPT_DIR}/../../../dolpa-bash-utils/bash-utils.sh"
if [[ ! -f "${BASH_UTILS_LOADER}" ]]; then
    echo "Error: dolpa‑bash‑utils loader not found: ${BASH_UTILS_LOADER}" >&2
    exit 1
fi
# shellcheck source=/dev/null
source "${BASH_UTILS_LOADER}"

# Configure Bash Utilites
BASH_UTILS_FORCE_COLOR=true   # force‑enable colored output (for logs, tables, …) even if not running in a terminal (e.g. when redirecting to a file); the shared library will handle this gracefully and disable colors if the output is not a TTY

BASH_UTILS_LOG_LEVEL="trace"  # default log level for the shared logging library (can be overridden by the environment variable BASH_UTILS_LOG_LEVEL or the system config files)

BASH_UTILS_VERBOSE="true"     # enable verbose logging for the shared library (e.g. to log debug information about argument parsing, configuration loading, …); can be overridden by the environment variable BASH_UTILS_VERBOSE or the system config files

# --------------------------------------------------------------------
#  Load system configuration files (they may overwrite the defaults)
# --------------------------------------------------------------------
# 1) Local system config (per‑machine)
log_info "Loading local system config from ${SYSTEM_CONFIG_LOCAL_FILE}"
if [[ -f "${SYSTEM_CONFIG_LOCAL_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${SYSTEM_CONFIG_LOCAL_FILE}"
else
    log_warning "No local system config found at ${SYSTEM_CONFIG_LOCAL_FILE} – using defaults"
fi

# Load global benchmark configuration
GLOBAL_BENCHMARK_CONFIG_FILE="${SCRIPT_DIR}/../../etc/benchmark.config.sh"
log_info "Loading global benchmark config from ${GLOBAL_BENCHMARK_CONFIG_FILE}"
if [[ -f "${GLOBAL_BENCHMARK_CONFIG_FILE}" ]]; then
    # shellcheck source=/dev/null
    source "${GLOBAL_BENCHMARK_CONFIG_FILE}"
else
    log_warning "No global benchmark config found at ${GLOBAL_BENCHMARK_CONFIG_FILE} – using defaults"
fi

# 2) Game config (defaults for the specific game, shared across all machines – expected to live in the same folder as this script, but can be overridden by the environment variable GAME_BENCHMARK_CONFIG)
log_info "Loading game benchmark config from ${GAME_BENCHMARK_CONFIG_DEFAULT}"
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
env_default BENCHMARK_TIMEOUT_SECONDS "$(( BENCHMARK_TIMEOUT_MINUTES * 60 ))"

# Default user‑settings folder (Steam‑Play “compatdata” path)
env_default USER_SETTINGS_FOLDER "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/AppData/Local/${GAME_CREATOR_STUDIO}${GAME_NAME}/"

# Default benchmark results source directory (where the game writes its CSVs)
env_default BENCHMARK_RESULTS_SOURCE_DIR "${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/${GAME_CREATOR_STUDIO}${GAME_NAME}/benchmarkResults/"

# --------------------------------------------------------------------
#  Load the benchmark‑specific test definitions
# --------------------------------------------------------------------
#   tests.conf.sh   – associative array  TESTS[<name>]=<command>
#   groups.conf.sh  – associative array  TEST_GROUPS[<group>]="<test1> <test2> ..."
# --------------------------------------------------------------------
# (Both files are expected to live in the same directory as this script)

# Load the tests config file (defines the TESTS array)
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
if ! validate_file "$TESTS_CONFIG_FILE" "Tests config file"; then
    exit 1
fi
source "$TESTS_CONFIG_FILE"

# Load the groups config file (defines the TEST_GROUPS array)
GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.conf.sh"
if ! validate_file "$GROUPS_CONFIG_FILE" "Groups config file"; then
    exit 1
fi
source "$GROUPS_CONFIG_FILE"

# List available groups available
list_groups() {
    local g
    for g in "${!TEST_GROUPS[@]}"; do
        echo "  $g: ${TEST_GROUPS[$g]}"
    done | sort
}

# List available tests
list_tests() {
    local t
    echo Available tests:
    for t in "${!TESTS[@]}"; do
        echo "  $t"
    done | sort
}

# TODO: implement this function to list available graphic settings (e.g. quality presets, ray tracing modes, upscaling options, …) for use in the test definitions and documentation; you can adapt it to your specific game and settings structure
list_graphic_settings() {
    log_info "TODO: implement this function of Available graphic settings (for use in test definitions)"
}

# List available tests in a formatted table
list_tests_table() {
    local t
    echo "  --------------------------------------------------------------------------------------------------------------------------------"
    printf "  %-2s %-45s %-4s %-6s %-8s %-11s %-11s %-11s %-4s %-10s %-8s\n" \
        "Av" "TEST" "DX" "RS" "RS-TYPE" "RS-PRESET" "RESOLUTION" "QUALITY" "RT" "RT-PRESET" "FG"
    echo "  --------------------------------------------------------------------------------------------------------------------------------"

    for t in "${!TESTS[@]}"; do
        read -r dx rs rs_type rs_preset res quality rt rt_preset fg <<< "${TESTS[$t]}"
        local av
        # log_info "Profile file is: $SCRIPT_DIR/pro/${GAME_SHORT_NAME}.profile.${t}.${GAME_PROFILE_EXTENSION}"
        if [[ -f "$SCRIPT_DIR/profiles/${GAME_SHORT_NAME}.profile.${t}.${GAME_PROFILE_EXTENSION}" ]]; then
            av=$(ansi_green "✓")
        else
            av=$(ansi_red "✗")
        fi
        printf "  %-2s %-45s %-4s %-6s %-8s %-11s %-11s %-11s %-4s %-10s %-8s\n" \
            "$av " "$(str_shorten 45 "$t")" "$dx" "$rs" "$rs_type" "$rs_preset" "$res" "$quality" "$rt" "$rt_preset" "$fg"
    done | sort
    echo "  --------------------------------------------------------------------------------------------------------------------------------"
    echo "      $(ansi_green "✓") - profile file is available, ready to run"
    echo "      $(ansi_red "✗") - profile file is not available for this test"
    echo "    Run: $(basename "$0") --list to get full tests names"
}

show_test() {
    log_info "Showing test definition for test name: '$1'"
    local test
    test="$1"
    if [[ ! "${TESTS[$test]+isset}" ]]; then
        log_error "Unknown test '$test'. Use --list to see available tests."
        return 1
    fi
    read -r dx rs rs_type rs_preset res quality rt rt_preset fg <<< "${TESTS[$test]}"
    echo "Test definition for '$test':"
    echo "  DX (DirectX)                        : $(str_upper $dx)"
    echo "  RS (Resolution Scaling)             : $rs"
    echo "  RS-TYPE (Resolution Scaling Type)   : $rs_type"
    echo "  RS-PRESET (Resolution Scaling Preset): $rs_preset"
    echo "  RESOLUTION (Screen Resolution)      : $res"
    echo "  QUALITY (Graphics Quality)          : $quality"
    echo "  RT (Ray Tracing)                    : $rt"
    echo "  RT-PRESET (Ray Tracing Preset)      : $rt_preset"
    echo "  FG (Frame Generation)               : $fg"
}

list_resolutions() {
    local r
    for r in "${!GAME_RESOLUTIONS[@]}"; do
        echo "  $r: ${GAME_RESOLUTIONS[$r]}"
    done | sort
}

benchmark_timestamp() {
    time_format_epoch "$(time_epoch)" "%Y%m%d_%H%M%S" local
}

validate_runtime_dependencies() {
    # Check if the required tools for the benchmark are installed (e.g. gnome-screenshot for taking screenshots, xdotool for automating menu navigation, …); you can extend this function to check for other dependencies as needed
    if [[ ${NEED_TO_TAKE_SCREENSHOT_OF_RESULTS:-false} == true ]]; then
        if ! command_exists gnome-screenshot; then
            log_error "gnome-screenshot is required to take screenshots of benchmark results. Please install it: sudo apt update && sudo apt install -y gnome-screenshot"
            return 1
        fi
        if ! command_exists magick; then
            log_error "ImageMagick (magick) is required to process benchmark screenshots. Please install it: sudo apt update && sudo apt install -y imagemagick"
            return 1
        fi
        log_info "Screenshots of benchmark results will be taken using gnome-screenshot."
    fi

    # If we need to automate menu navigation to start the benchmark, check if xdotool is installed; you can adapt this to your specific game and how you plan to automate the menu navigation (e.g. by sending keystrokes, mouse clicks, …)
    if [[ ${NEED_TO_CLOCK_BENCHMARK_IN_MENU:-false} == true ]]; then
        if ! command_exists xdotool; then
            log_error "xdotool is not installed; automatic benchmark menu navigation is unavailable."
            return 1
        fi
    fi

    return 0
}

register_background_helper() {
    local helper_pid
    helper_pid="$1"

    if [[ -n "$helper_pid" ]]; then
        BENCHMARK_HELPER_PIDS+=("$helper_pid")
    fi
}

cleanup_background_helpers() {
    local helper_pid

    for helper_pid in "${BENCHMARK_HELPER_PIDS[@]}"; do
        if exec_is_running "$helper_pid"; then
            exec_kill "$helper_pid" >/dev/null 2>&1 || true
        fi
    done

    BENCHMARK_HELPER_PIDS=()
}

# --------------------------------------------------------------------
#  Helper functions (you can extend them later)
# --------------------------------------------------------------------
show_help() {
    cat <<EOF
${GAME_NAME} Benchmark runner

Usage:  $(basename "$0") [options] [test …]

Options:
  -h, --help               Show this help
  --list                   List all available tests
  --groups                 List all defined groups
  --validate-profiles      Validate that all benchmark profiles exist
  --proton                 Run the game in Proton mode (default)
  --native                 Run the game in native Linux mode
  --gamemode               Run the game under gamemode
  --mangohud               Enable MangoHud overlay for all tests (if installed and detected by the shared library)
  --group <name>           Run every test from the named group
  --show-test              Show the test definition for the specified test name (e.g. "native-1080p-low-rt-off")
  --timeout-minutes <N>    Set per‑test timeout (default: ${BENCHMARK_TIMEOUT_MINUTES} min)
  --all                    Run **all** tests defined in config/tests.config.sh

Available resolutions:
$(list_resolutions)

Available graphic settings:
$(list_graphic_settings)

Available tests:
$(list_tests_table)

Available groups:
$(list_groups)

SYSTEM CONFIG FILES (loaded in order):
    1) ${SYSTEM_CONFIG_LOCAL_FILE} (optional, selected by SYSTEM_NAME=${SYSTEM_NAME})
    2) BENCHMARK_CONFIG=/path/to/file.conf.sh (optional override)

System selection override:
    SYSTEM_NAME=MY_MACHINE $0 --group quick-4k"

EOF
}

# Helper function to check if xdotool is installed (used for automating menu navigation to start the benchmark); you can extend this function to check for other required tools as well
go_to_menu_and_run_bench() {
	local win_id=""
	local attempts=$((AUTO_CLICK_TIMEOUT_SEC * 2))
	for _ in $(seq 1 "$attempts"); do
		win_id="$(xdotool search --name "ASSASSIN'S CREED VALHALLA Benchmark" 2>/dev/null | head -n1 || true)"
		if [[ -n "$win_id" ]]; then
			local width height
			width="$(xdotool getwindowgeometry --shell "$win_id" 2>/dev/null | awk -F= '/^WIDTH=/{print $2}')"
			height="$(xdotool getwindowgeometry --shell "$win_id" 2>/dev/null | awk -F= '/^HEIGHT=/{print $2}')"

			if [[ -z "$width" || -z "$height" ]]; then
				width=1600
				height=900
			fi

			local run_all_x_default=$((width - 120))
			local run_all_y_default=$((height - 34))
			local run_all_x="${RUN_ALL_BUTTON_X:-$run_all_x_default}"
			local run_all_y="${RUN_ALL_BUTTON_Y:-$run_all_y_default}"
			local run_all_screen_x="${RUN_ALL_BUTTON_SCREEN_X:-}"
			local run_all_screen_y="${RUN_ALL_BUTTON_SCREEN_Y:-}"
			local confirm_yes_x="${CONFIRM_YES_SCREEN_X:-}"
			local confirm_yes_y="${CONFIRM_YES_SCREEN_Y:-}"
			local preset_x_default=$((width / 5))
			local preset_y_default=$((height / 2))
			local preset_x="${PRESET_ITEM_X:-$preset_x_default}"
			local preset_y="${PRESET_ITEM_Y:-$preset_y_default}"
			local preset_screen_x="${PRESET_ITEM_SCREEN_X:-}"
			local preset_screen_y="${PRESET_ITEM_SCREEN_Y:-}"

			if (( run_all_x < 1 )); then run_all_x=1; fi
			if (( run_all_y < 1 )); then run_all_y=1; fi
			if (( preset_x < 1 )); then preset_x=1; fi
			if (( preset_y < 1 )); then preset_y=1; fi

			xdotool windowactivate "$win_id" >/dev/null 2>&1 || true
			xdotool windowraise "$win_id" >/dev/null 2>&1 || true
			sleep 0.6

			# if [[ -n "$preset_screen_x" && -n "$preset_screen_y" ]]; then
			# 	for _ in $(seq 1 "$PRESET_CLICK_RETRIES"); do
			# 		xdotool mousemove --sync "$preset_screen_x" "$preset_screen_y" >/dev/null 2>&1 || true
			# 		xdotool click 1 >/dev/null 2>&1 || true
			# 		sleep 0.25
			# 	done
			# else
			# 	for _ in $(seq 1 "$PRESET_CLICK_RETRIES"); do
			# 		xdotool mousemove --window "$win_id" --sync "$preset_x" "$preset_y" >/dev/null 2>&1 || true
			# 		xdotool click --window "$win_id" 1 >/dev/null 2>&1 || true
			# 		sleep 0.25
			# 	done
			# fi

			sleep 0.35
			if [[ -n "$run_all_screen_x" && -n "$run_all_screen_y" ]]; then
				for _ in $(seq 1 "$RUN_ALL_CLICK_RETRIES"); do
					xdotool mousemove --sync "$run_all_screen_x" "$run_all_screen_y" >/dev/null 2>&1 || true
					xdotool click 1 >/dev/null 2>&1 || true
					sleep 0.25
				done
			else
				for _ in $(seq 1 "$RUN_ALL_CLICK_RETRIES"); do
					xdotool mousemove --window "$win_id" --sync "$run_all_x" "$run_all_y" >/dev/null 2>&1 || true
					xdotool click --window "$win_id" 1 >/dev/null 2>&1 || true
					sleep 0.25
				done
			fi

			sleep 0.35
			if [[ -n "$confirm_yes_x" && -n "$confirm_yes_y" ]]; then
				for _ in $(seq 1 "$CONFIRM_YES_CLICK_RETRIES"); do
					xdotool mousemove --sync "$confirm_yes_x" "$confirm_yes_y" >/dev/null 2>&1 || true
					xdotool click 1 >/dev/null 2>&1 || true
					sleep 0.3
				done
			fi
			return 0
		fi
		sleep 0.5
	done
	return 1
}

# Helper function to take a screenshot and save them in results folder for later analysis
# Arguments:
#   $1 – for how long to keep taking screenshots (in seconds, default: 300 seconds = 5 minutes)
#   $2 – how often to take screenshots (in seconds, default: 20 seconds)
#   $3 – number of screenshots to take (default: 1)
take_screenshots_every_after_delay() {
    local delay_seconds
    local each_seconds
    local counter

    delay_seconds="${1:-300}"
    each_seconds="${2:-20}"
    counter="${3:-1}"

    sleep "$delay_seconds"
    for i in $(seq 1 "$counter"); do
        gnome-screenshot -f ${results_folder}/screenshot_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}.png >/dev/null 2>&1 || true
        sleep "$each_seconds"
    done

    return 0
}

# Extract the results from the screenshots taken during the benchmark run and save them in a structured format (e.g. CSV) for later analysis; you can adapt it to how the benchmark results are displayed in the screenshots and what specific information you want to extract (e.g. average FPS, frametimes, …); if a custom function is defined in the game config file (e.g. custom_extract_benchmark_results_from_screenshots_ac_valhalla), it will be used instead of this default function; you can also customize this default function if needed
extract_benchmark_results_from_screenshots_to_results() {
    log_info "TODO: implement this function to extract benchmark results from screenshots (e.g. using OCR) and save them in a structured format (e.g. CSV) for later analysis; you can adapt it to your specific game and how the benchmark results are displayed in the screenshots"
    # try each screenshot taken during the benchmark run and extract the relevant information (e.g. average FPS, frametimes, …) using OCR or other methods; you can use tools like tesseract‑ocr for OCR, or if the game provides an API or a way to export the results in a structured format, you can use that instead

    # Get the posion of the benchmark results in the screenshots
    local position_w
    local position_h
    local position_x_offset
    local position_y_offset
    position_w="${BENCHMARK_SCREENSHOT_RESULTS_W:-}"
    position_h="${BENCHMARK_SCREENSHOT_RESULTS_H:-}"
    position_x_offset="${BENCHMARK_SCREENSHOT_RESULTS_X_OFFSET:-}"
    position_y_offset="${BENCHMARK_SCREENSHOT_RESULTS_Y_OFFSET:-}"
    for i in $(seq 1 "$_NUMBER_OF_SCREENSHOTS"); do
        # Implement OCR or other methods to extract benchmark results from each screenshot

        # Crop the image
        gm convert "${results_folder}/screenshot_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}.png" \
            -crop "${position_w}x${position_h}+${position_x_offset}+${position_y_offset}" \
            "${results_folder}/screenshot_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}_cropped.png"
        # imagemagick_output=$(magick convert ${results_folder}/screenshot_${SHORT_GAME_NAME}_${script_run_timestamp}_${i}.png -crop 800x600+100+100 +repage ${results_folder}/screenshot_cropped_${SHORT_GAME_NAME}_${script_run_timestamp}_${i}.png 2>&1)
        # extract the results

        # pre-process the image
        ffmpeg -i "${results_folder}/screenshot_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}_cropped.png" \
            -vf "format=gray,negate,eq=contrast=1.5" \
            "${results_folder}/screenshot_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}_cropped_processed.png"
            
        # extract text using tesseract OCR
        tesseract "${results_folder}/screenshot_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}_cropped_processed.png" \
            stdout --psm 11 -c tessedit_char_whitelist=0123456789., | tr -s '\n' ' ' | awk '{print $3}' > \
            ${results_folder}/result_${SHORT_GAME_NAME}_${test_name}_${script_run_timestamp}_${i}.txt
        
    done
}

validate_profiles() {
    local missing_count
    local profiles_dir

    profiles_dir="${SCRIPT_DIR}/profiles"
    missing_count=0

    if ! validate_directory "$profiles_dir" "Profiles directory"; then
        log_error "Profiles directory validation failed: ${profiles_dir} is not a valid directory."
        return 1
    fi
    
    log_info "Validating profile files in ${profiles_dir} ..."
    for test_name in "${!TESTS[@]}"; do
        # the command stored in TESTS[<name>] is expected to be a CSV‑profile path;
        # you may adapt the check to your own format.
        local profile_file
        profile_file="$SCRIPT_DIR/config/${GAME_SHORT_NAME}.profile.${test_name}.${GAME_PROFILE_EXTENSION}"
        if ! is_path_file "$profile_file"; then
            log_error "Missing benchmark profile for test: ${test_name}"
            ((missing_count++))
        fi
    done
    
    if [[ $missing_count -eq 0 ]]; then
        log_success "Profile validation passed: all test profiles exist."
        return 0
    fi

    log_error "Profile validation failed: ${missing_count} missing profile file(s)."
    return 1
}

# --------------------------------------------------------------------
#  The core “run a single test” routine
# Arguments:
#   $1 – test name (key in the TESTS array)
#   $2 – log file path
#   $3 – current test index (for logging)
#   $4 – total tests count (for logging)
# --------------------------------------------------------------------
run_test() {
    local test_name
    local logfile
    local test_index
    local total_tests

    test_name="$1"
    logfile="$2"
    test_index="${3:-0}"
    total_tests="${4:-0}"     # for logging purposes, if available


    if [[ ! "${TESTS[$test_name]+isset}" ]]; then
        log_to_file error "$logfile" "Unknown test '$test_name'. Use --list to see available tests."
        return 1
    fi

    # Test parameter Format: 
    #   0. RS: Resolution scaling 
    #   1. RST: Resolution scaling type
    #   2. RS-PRESET: Resolution scaling preset
    #   3. RESOLUTION: Target resolution
    #   4. QUALITY: Graphics quality
    #   5. RT: Ray tracing
    #   6. RT-PRESET: Ray tracing preset
    #   7. FG: Frame generation
    local params

    local rs
    local rs_type
    local rs_preset

    local resolution
    local quality
    local rt
    local rt_preset
    local frame_generation


    params=(${TESTS[$test_name]})

    rs="${params[0]}"
    rs_type="${params[1]}"
    rs_preset="${params[2]}"

    resolution="${params[3]}"
    quality="${params[4]}"
    rt="${params[5]}"
    rt_preset="${params[6]}"
    frame_generation="${params[7]}"

    if [[ "$test_index" -gt 0 && "$total_tests" -gt 0 ]]; then
        log_to_file info "$logfile" "Running test ($test_index/$total_tests): $test_name"
    else
        log_to_file info "$logfile" "Running test: $test_name"
    fi

    log_to_file info "$logfile" "Parameters: rs=$rs rs_type=$rs_type rs_preset=$rs_preset resolution=$resolution quality=$quality rt=$rt rt_preset=$rt_preset fg=$frame_generation"

    # Apply settings and run benchmark
    if run_bench "$rs" "$rs_type" "$rs_preset" "$resolution" "$quality" "$rt" "$rt_preset" "$frame_generation" "$logfile" "$test_name" "$logfile" "$test_name"; then
        log_to_file success "$logfile" "$test_name completed successfully"
        return 0
    else
        log_to_file error "$logfile" "$test_name failed"
        return 1
    fi
}

# Function to launch with a specific upscaling mode
run_bench() {
    local rs
    local rs_type
    local rs_preset
    local resolution
    local quality
    local rt
    local rt_preset
    local frame_generation
    local logfile
    local test_name
    local proton_path
    local game_path
    local -a proton_candidates
    local -a game_candidates
    local candidate_path

    rs=$1
    rs_type=$2
    rs_preset=$3
    resolution=$4
    quality=${5:-low}
    rt=${6:-off}
    rt_preset=${7:-off}
    frame_generation=${8:-off}
    logfile=${9:-""}
    test_name=${10:-""}

    # Find Proton installation - check Steam root and custom library possible locations
    proton_candidates=(
        "$STEAM_PATH/compatibilitytools.d/$PROTON_VERSION"
        "$STEAM_ROOT/compatibilitytools.d/$PROTON_VERSION"
    )
    proton_path=""
    for candidate_path in "${proton_candidates[@]}"; do
        if is_path_directory "$candidate_path"; then
            proton_path="$candidate_path"
            break
        fi
    done
    if [[ -z "$proton_path" ]]; then
        log_to_file error "$logfile" "Proton $PROTON_VERSION not found"
        return 1
    fi

    # Find game installation - check multiple possible locations
    game_candidates=(
        "$STEAM_PATH/steamapps/common/$GAME_NAME"
        "$STEAM_ROOT/steamapps/common/$GAME_NAME"
        "$CUSTOM_LIBRARY_PATH/steamapps/common/$GAME_NAME"
    )
    game_path=""
    for candidate_path in "${game_candidates[@]}"; do
        if is_path_directory "$candidate_path"; then
            game_path="$candidate_path"
            break
        fi
    done
    if [[ -z "$game_path" ]]; then
        log_to_file error "$logfile" "$GAME_NAME not found in any of these locations:"
        log_to_file error "$logfile" "  - $STEAM_PATH/steamapps/common/$GAME_NAME"
        log_to_file error "$logfile" "  - $STEAM_ROOT/steamapps/common/$GAME_NAME"
        log_to_file error "$logfile" "  - $CUSTOM_LIBRARY_PATH/steamapps/common/$GAME_NAME"
        return 1
    fi

    # Final check for the game executable
    local exe_path
    exe_path="$game_path/$GANME_EXE_PATH$GAME_EXE"
    if ! is_path_file "$exe_path"; then
        log_to_file error "$log" "Game executable not found at $exe_path"
        return 1
    fi
    
    # Set up environment
    export STEAM_COMPAT_DATA_PATH="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"

    local -a launch_game_args
    launch_game_args=()
    # Build Launch arguments based on the test parameters; you will need to adapt this to your game's specific command‑line options or configuration file handling
    for arg in $GAME_LAUNCH_ARGS; do
        launch_game_args+=("$arg")
    done

    apply_setting "$rs" "$rs_type" "$rs_preset" "$resolution" "$quality" "$rt" "$rt_preset" "$frame_generation" "$logfile" "$test_name" || return 1

    local -a proton_run_cmd
    proton_run_cmd=("$proton_path/proton")

    # Enable gamemoderun and mangohud if requested (and available); they will be injected into the Proton launch command
    if [[ "$ENABLE_GAMEMODERUN" -eq 1 ]]; then
        if app_is_installed gamemoderun; then
            proton_run_cmd=(gamemoderun "${proton_run_cmd[@]}")
        else
            log_to_file error "$log" "--gamemode requested but 'gamemoderun' was not found in PATH."
            return 1
        fi
    fi
    # Enable MangoHud if requested; it will be injected into the Proton launch command via the MANGOHUD=1 environment variable
    if [[ "$ENABLE_MANGOHUD" -eq 1 ]]; then
        if app_is_installed mangohud; then
            proton_run_cmd=("MANGOHUD=1" "${proton_run_cmd[@]}")
        else
            log_to_file error "$log" "--mangohud requested but 'mangohud' was not found in PATH."
            return 1
        fi
    fi

    # Check if the 'timeout' command is available (part of coreutils); we rely on it to enforce time limits on the benchmark runs
    if ! command_exists timeout; then
        log_to_file error "$log" "Required command 'timeout' not found. Please install coreutils."
        return 1
    fi

    # Build the full launch command with environment variables, Proton, and game executable``
    local -a full_launch_cmd=(
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
        "${launch_game_args[@]}"

    )

    local full_launch_cmd_pretty=""
    printf -v full_launch_cmd_pretty '%q ' "${full_launch_cmd[@]}"
    log_to_file info "$log" "Full launch command: cd $(printf '%q' "$game_path") && ${full_launch_cmd_pretty% }"

    # Go to menu and run the benchmark (you will need to adapt this to your specific game, e.g. by sending keystrokes or mouse clicks to navigate the menu and start the benchmark; the example below is just a placeholder and may not work for your game)
    if [[ ${NEED_TO_CLOCK_BENCHMARK_IN_MENU} ]]; then
        go_to_menu_and_run_bench &
        register_background_helper "$!"
    fi
    if [[ ${NEED_TO_TAKE_SCREENSHOT_OF_RESULTS} ]]; then
        take_screenshots_every_after_delay 15 &
        register_background_helper "$!"
    fi

    local exit_code
    (
        cd "$game_path" || exit 1
        "${full_launch_cmd[@]}"
    ) >>"$logfile" 2>&1
    exit_code=$?

    # Check if the benchmark timed out (timeout exits with 124 if the command times out, and 137 if it had to be
    if [[ $exit_code -eq 124 || $exit_code -eq 137 ]]; then
        log_to_file warning "$logfile" "Benchmark timed out after ${BENCHMARK_TIMEOUT_SECONDS}s."
    fi

    # Kill the game process if it's still running after the timeout (in case it didn't exit cleanly); we use pkill with a pattern matching the game executable name and the crash reporter (if it exists), and we ignore errors in case the processes are already closed
    env \
        "STEAM_COMPAT_CLIENT_INSTALL_PATH=$STEAM_PATH" \
        "STEAM_COMPAT_DATA_PATH=$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
        "$proton_path/proton" run wineserver -k >>"$logfile" 2>&1 || true

    # Kill Game executable and Crash Reporter processes if they are still running (using pkill with a pattern matching the game executable name and the crash reporter, and ignoring errors in case the processes are already closed)
    pkill -f "$GAME_EXE|CrashReporter" >/dev/null 2>&1 || true

    # Check the exit code of the benchmark run and log accordingly
    if [[ $exit_code -eq 0 ]]; then
        # If the benchmark completed successfully, log a success message; otherwise, log an error with the exit code
        log_to_file success "$logfile" "Benchmark completed successfully for $mode"
    else
        # If the benchmark failed, log an error message with the exit code
        log_to_file error "$logfile" "Benchmark failed for $mode (exit code: $exit_code)"
    fi

    # 
    if [[ $exit_code -eq 0 && ${NEED_TO_TAKE_SCREENSHOT_OF_RESULTS} ]]; then
        # If the benchmark completed successfully, it's time to extract the results from the screenshots; you can implement the extraction logic in the extract_benchmark_results_from_screenshots_to_results function, or if you have a custom function for this specific game, you can call it here (just make sure to define it in the game config file or the global benchmark config file)
        if declare -F "$CUSTOM_EXTRACT_BENCHMARK_RESULTS_FROM_SCREENSHOTS_FUNCTION" > /dev/null; then
            log_to_file info "$logfile" "Extracting benchmark results from screenshots using custom function: $CUSTOM_EXTRACT_BENCHMARK_RESULTS_FROM_SCREENSHOTS_FUNCTION"
            "$CUSTOM_EXTRACT_BENCHMARK_RESULTS_FROM_SCREENSHOTS_FUNCTION"
        else
            log_to_file info "$logfile" "Custom function for extracting benchmark results from screenshots is not defined. Using the default extraction."
            extract_benchmark_results_from_screenshots_to_results
        fi
    fi

    # Copy the benchmark result file (e.g. CSV) to the results folder with a name that includes the test name, mode, resolution, and GPU metadata; you will need to adapt the source file name and the naming format to your specific game and benchmark output
    if [[ NEED_TO_TAKE_SCREENSHOT_OF_RESULTS -eq 0 ]]; then
        # If we took screenshots of the benchmark results, we assume that the extracted results are saved in a structured format (e.g. CSV) in the results folder, and we copy that file; you can adapt this to your specific extraction logic and output format
        if [[ -n "$test_name" ]]; then
            copy_benchmark_result_file "$test_name" "$logfile"
        else
            copy_benchmark_result_file "manual-${mode}-${res}" "$logfile"
        fi
    fi
    
    sleep 15   # give the game time to close cleanly
    return $exit_code
}


copy_benchmark_result_file() {
    local test_name
    local logfile
    local source_dir
    local output_dir

    test_name="$1"
    logfile="$2"
    source_dir="$BENCHMARK_RESULTS_SOURCE_DIR"
    output_dir="$BENCHMARK_RESULTS_OUTPUT_DIR"

    ensure_directory "$output_dir"

    # Use the provided SCRIPT_RUN_TIMESTAMP environment variable if set; otherwise, generate a new timestamp for this run. This allows for consistent timestamps across multiple tests in the same run, while still having unique timestamps for separate runs.
    if [[ -z "$script_run_timestamp" ]]; then
        script_run_timestamp="$(benchmark_timestamp)"
    else
        script_run_timestamp="$SCRIPT_RUN_TIMESTAMP"
    fi

    # Check results source directory
    if ! validate_directory "$source_dir"; then
        log_to_file warning "$logfile" "Benchmark source directory not found: $source_dir"
        return 0
    fi

    local latest_benchmark_dir
    latest_benchmark_dir="$(find "$source_dir" -mindepth 1 -maxdepth 1 -type d -name "benchmark_*" -printf "%T@ %p\n" 2>/dev/null | sort -nr | head -n1 | cut -d' ' -f2-)"

    if [[ -z "$latest_benchmark_dir" ]] || ! is_path_directory "$latest_benchmark_dir"; then
        log_to_file warning "$logfile" "No benchmark_* directory found in $source_dir"
        return 0
    fi

    local source_file="$latest_benchmark_dir/summary.json"
    if ! is_path_file "$source_file"; then
        log_to_file warning "$logfile" "summary.json not found in latest benchmark directory: $latest_benchmark_dir"
        return 0
    fi

    local destination_file="$output_dir/${GAME_ID}_result_${test_name}_${GPU_METADATA_TAG}_${SCRIPT_RUN_TIMESTAMP}.json"
    if copy_file "$source_file" "$destination_file"; then
        log_to_file success "$logfile" "Copied benchmark result: $destination_file"
    else
        log_to_file warning "$logfile" "Failed to copy benchmark result from $source_file"
    fi
}

# --------------------------------------------------------------------
#  Helper functions for GPU metadata detection and sanitization (used for tagging results with GPU info)
sanitize_filename_segment() {
    local value
    value="$1"
    value="$(str_lower "$value")"
    value="$(str_trim "$value")"
    value="$(echo "$value" | sed 's/[[:space:]]\+/_/g')"
    value="$(echo "$value" | sed 's/[^a-z0-9._-]/-/g')"
    value="$(echo "$value" | sed 's/[-_][-_]*/-/g')"
    value="$(echo "$value" | sed 's/^[-_.]*//;s/[-_.]*$//')"
    if [[ -z "$value" ]]; then
        value="unknown"
    fi
    echo "$value"
}

# Detect GPU metadata using nvidia-smi (for NVIDIA GPUs) or lspci (for others) and sanitize it for use in filenames and tags
detect_gpu_metadata() {
    local gpu_model
    local gpu_vram
    local gpu_driver
    gpu_model="unknown-gpu"
    gpu_vram="unknown-vram"
    gpu_driver="unknown-driver"

    # NVIDIA GPUs: use nvidia-smi to get the GPU name, total VRAM, and driver version
    if command_exists nvidia-smi; then
        local gpu_line
        gpu_line="$(nvidia-smi --query-gpu=name,memory.total,driver_version --format=csv,noheader,nounits 2>/dev/null | head -n1)"
        if [[ -n "$gpu_line" ]]; then
            local model_raw vram_raw driver_raw
            IFS=',' read -r model_raw vram_raw driver_raw <<< "$gpu_line"
            model_raw="$(str_trim "$model_raw")"
            vram_raw="$(str_trim "$vram_raw")"
            driver_raw="$(str_trim "$driver_raw")"

            [[ -n "$model_raw" ]] && gpu_model="$model_raw"
            [[ -n "$vram_raw" ]] && gpu_vram="${vram_raw}mb"
            [[ -n "$driver_raw" ]] && gpu_driver="$driver_raw"
        fi
    # Other GPUs: use lspci to get the GPU model (VRAM and driver info may not be available)
    elif command_exists lspci; then
        local lspci_line
        lspci_line="$(lspci 2>/dev/null | grep -Ei 'vga|3d|display' | head -n1)"
        if [[ -n "$lspci_line" ]]; then
            gpu_model="$lspci_line"
        fi
    fi

    # Set the global GPU_METADATA_TAG variable to a sanitized combination of the detected GPU metadata (e.g. "nvidia-rtx-3080_10gb_driver-525.60.13")
    GPU_METADATA_TAG="$(sanitize_filename_segment "$gpu_model")_$(sanitize_filename_segment "$gpu_vram")_$(sanitize_filename_segment "$gpu_driver")"
}

# --------------------------------------------------------------------
#  Main entry point – parses arguments, creates a log file and executes
# --------------------------------------------------------------------
main() {
    # ----------------------------------------------------------------
    #  Runtime state variables
    # ----------------------------------------------------------------
    local script_run_timestamp
    script_run_timestamp="$(benchmark_timestamp)"
    SCRIPT_RUN_TIMESTAMP="$script_run_timestamp"
    local logfile
    logfile="${SCRIPT_DIR}/${GAME_SHORT_NAME}_benchmark_${script_run_timestamp}.log"

    # ----------------------------------------------------------------
    #  Command‑line parsing (exactly the options you asked for)
    # ----------------------------------------------------------------
    
    local -a normalized_args
    local -a selected_tests
    local -a tests_to_run
    local -a selected_groups
    local group_name
    local timeout_override
    local proton_version_override
    local run_all
    local total_tests_count
    local cli_gamemode_override
    local cli_mangohud_override
    local cli_proton_override
    local cli_native_override
    local show_test

    # run related parameters
    local failed_tests
    local successful_tests
    local current_test_index

    run_all=false
    normalized_args=()
    selected_tests=()
    tests_to_run=()
    selected_groups=()
    total_tests_count=0
    cli_gamemode_override=false
    cli_mangohud_override=false
    cli_proton_override=false
    cli_native_override=false

    detect_gpu_metadata  # populate GPU_METADATA_TAG with the detected GPU info (sanitized for use in filenames and tags)

    for arg in "$@"; do
        case "$arg" in
            -h)
                normalized_args+=("--help")
                ;;
            *)
                normalized_args+=("$arg")
                ;;
        esac
    done

    args_set_flags --help --list --groups --validate-profiles --gamemode --mangohud --proton --native --all
    args_set_values --show-test --proton-version --group --timeout-minutes

    log_debug "Normalized arguments: ${normalized_args[*]}"
    
    args_parse "${normalized_args[@]}"

    for arg in "${ARGS_POSITIONAL[@]}"; do
        if [[ "$arg" == -* ]]; then
            log_error "Unknown option $arg"
            log_error "Use --help for usage information."
            exit 1
        fi
    done

    if args_get_flag --help >/dev/null 2>&1; then
        show_help
        exit 0
    fi

    if args_get_flag --list >/dev/null 2>&1; then
        list_tests
        exit 0
    fi

    if args_get_flag --groups >/dev/null 2>&1; then
        list_groups
        exit 0
    fi

    if args_get_flag --validate-profiles >/dev/null 2>&1; then
        if validate_profiles; then
            exit 0
        else
            exit 1
        fi
    fi

    if args_get_flag --gamemode >/dev/null 2>&1; then
        ENABLE_GAMEMODERUN=1
        cli_gamemode_override=true
    fi

    if args_get_flag --mangohud >/dev/null 2>&1; then
        ENABLE_MANGOHUD=1
        cli_mangohud_override=true
    fi

    if args_get_flag --proton >/dev/null 2>&1; then
        ENABLE_PROTON=1
        cli_proton_override=true
    fi

    if args_get_flag --native >/dev/null 2>&1; then
        ENABLE_PROTON=0
        cli_native_override=true
    fi

    show_test="$(args_get_value --show-test)"
    log_info "show_test value: $show_test"
    if [[ -n "$show_test" ]]; then
        show_test "$show_test"
        exit 0
    else
        log_info "No specific test specified to show with --show-test; ignoring."
    fi

    proton_version_override="$(args_get_value --proton-version)"
    if [[ -n "$proton_version_override" ]]; then
        if [[ "$proton_version_override" == -* ]]; then
            log_error "--proton-version requires a version string (e.g. GE-Proton10-32)"
            exit 1
        fi
        PROTON_VERSION="$proton_version_override"
        ENABLE_PROTON=1
        cli_proton_override=true
    fi

    timeout_override="$(args_get_value --timeout-minutes)"
    if [[ -n "$timeout_override" ]]; then
        if [[ ! "$timeout_override" =~ ^[0-9]+$ || "$timeout_override" -le 0 ]]; then
            log_error "--timeout-minutes requires a positive integer value"
            exit 1
        fi
        BENCHMARK_TIMEOUT_MINUTES="$timeout_override"
        BENCHMARK_TIMEOUT_SECONDS=$((BENCHMARK_TIMEOUT_MINUTES * 60))
    fi

    args_get_values --group selected_groups
    for group_name in "${selected_groups[@]}"; do
        if [[ -z "$group_name" || "$group_name" == -* ]]; then
            log_error "--group requires a group name"
            exit 1
        fi
        if [[ ! "${TEST_GROUPS[$group_name]+isset}" ]]; then
            log_error "Unknown test group '$group_name'. Use --groups to see available groups."
            exit 1
        fi
        read -ra group_tests <<< "${TEST_GROUPS[$group_name]}"
        tests_to_run+=("${group_tests[@]}")
    done

    if args_get_flag --all >/dev/null 2>&1; then
        run_all=true
    fi

    selected_tests=("${ARGS_POSITIONAL[@]}")
    tests_to_run+=("${selected_tests[@]}")

    # Check if Steam directory exists
    if ! validate_directory "$STEAM_PATH" "Steam directory"; then
        exit 1
    fi

    if ! validate_runtime_dependencies; then
        exit 1
    fi
    
    # Ensure log directory exists
    ensure_directory "${SCRIPT_DIR}/logs"

    # ----------------------------------------------------------------
    #  If “--all” was given, replace the explicit list with **all** tests
    # ----------------------------------------------------------------
    if [[ "$run_all" == "true" ]]; then
        tests_to_run=()
        for test_name in "${!TESTS[@]}"; do
            tests_to_run+=("$test_name")
        done
    fi

    # ----------------------------------------------------------------
    #  Prepare the log file
    # ----------------------------------------------------------------
    log_to_file "info" "$logfile" "=================================================================="
    log_to_file "info" "$logfile" "${GAME_NAME} Benchmark – $(time_now_iso8601_local)"
    log_to_file "info" "$logfile" "=================================================================="
    log_to_file "info" "$logfile" "Proton version   : ${PROTON_VERSION}"
    log_to_file "info" "$logfile" "Steam library    : ${CUSTOM_LIBRARY_PATH}"
    log_to_file "info" "$logfile" "User settings    : ${USER_SETTINGS_FOLDER}"
    log_to_file "info" "$logfile" "Steam Path       : ${STEAM_PATH}"
    log_to_file "info" "$logfile" "Proton Version   : ${PROTON_VERSION}"
    log_to_file "info" "$logfile" "GPU Metadata     : ${GPU_METADATA_TAG}"
    log_to_file "info" "$logfile" "Result source    : ${BENCHMARK_RESULTS_SOURCE_DIR}"
    log_to_file "info" "$logfile" "Result destination: ${BENCHMARK_RESULTS_OUTPUT_DIR}"
    log_to_file "info" "$logfile" "Timeout per test : ${BENCHMARK_TIMEOUT_MINUTES} min (${BENCHMARK_TIMEOUT_SECONDS}s)"
    log_to_file "info" "$logfile" "Gamemode         : $(( ENABLE_GAMEMODERUN ))"
    log_to_file "info" "$logfile" "Mangohud         : $(( ENABLE_MANGOHUD ))"
    log_to_file "info" "$logfile" "=================================================================="
    log_to_file "info" "$logfile" ""


    # ----------------------------------------------------------------
    # Determine which tests to run based on the command‑line arguments and the defined groups
    # (the TESTS array is defined in the sourced config/tests.conf.sh file)
    # ----------------------------------------------------------------
    if [[ "$run_all" == "true" ]]; then
        # runn all the tests defined in the TESTS array
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
        tests_to_run=("${DEFAULT_TEST_TO_RUN}")
        log_to_file info "$logfile" "No tests specified, running default test: ${DEFAULT_TEST_TO_RUN}"
    else
        # tests specified via command line (either directly or through groups)
        log_to_file info "$logfile" "Running selected tests from command line and groups..."
        # Sort tests for consistent order
        IFS=$'\n' tests_to_run=($(sort <<<"${tests_to_run[*]}"))
        unset IFS
    fi

    total_tests_count=${#tests_to_run[@]}
    
    log_to_file info "$logfile" "Tests to run: ${tests_to_run[*]}"
    log_to_file info "$logfile" "Results will be saved to: $logfile"
    
    # Run the selected tests
    failed_tests=()
    successful_tests=()
    current_test_index=0

    trap_on_exit cleanup_background_helpers
    trap_signals INT TERM
    
    # ----------------------------------------------------------------
    #  Run the selected tests one‑by‑one, logging everything through the
    #  shared library (log_to_file writes to both stdout and the log file)
    # ----------------------------------------------------------------
    for test_name in "${tests_to_run[@]}"; do
        current_test_index=$((current_test_index + 1))
        log_to_file info "$logfile" "======================================="
        if run_test "$test_name" "$logfile" "$current_test_index" "$total_tests_count"; then
            successful_tests+=("$test_name")
        else
            failed_tests+=("$test_name")
        fi
    done
    log_to_file info "$logfile" "======================================="
    log_to_file info "$logfile" "Benchmark completed. Successful tests: ${#successful_tests[@]}, Failed tests: ${#failed_tests[@]}"
    if [[ ${#failed_tests[@]} -gt 0 ]]; then
        log_to_file error "$logfile" "Failed tests: ${failed_tests[*]}"
    fi
    log_to_file info "$logfile" "======================================="
}

# --------------------------------------------------------------------
#  Execute
# --------------------------------------------------------------------
main "$@"