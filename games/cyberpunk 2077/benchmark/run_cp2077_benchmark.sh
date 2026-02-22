#!/usr/bin/env bash
# -------------------------------------------------
# Cyberpunk 2077 DLSS/FSR Benchmark on Ubuntu (Steam)
# -------------------------------------------------
GAME_ID=1091500                                     # Steam AppID for Cyberpunk 2077
STEAM_PATH="${HOME}/.local/share/Steam"             # Main Steam installation
STEAM_ROOT="${HOME}/.steam/root"
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"    # Custom Steam library path
PROTON_VERSION="GE-Proton9-27"                      # Adjust version as needed

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

ally_setting() {
    local mode=$1
    local resolution=$2
    local quality_preset=$3
    local ray_tracing=$4
    local frame_generation=$5
    local log=$6
    local output_array_name=$7
    local -n launch_args_ref="$output_array_name"

    local settings_dir="${STEAM_COMPAT_DATA_PATH}/pfx/drive_c/users/steamuser/AppData/Local/CD Projekt Red/Cyberpunk 2077"
    local profile_dir="${SCRIPT_DIR}/profiles"
    local target_settings_file="${settings_dir}/UserSettings.json"

    case "$mode" in
        none)
            mode="native"
            ;;
        dlss|fsr2|xess|native)
            ;;
        *)
            echo "Error: Unsupported mode '$mode'. Supported: dlss, fsr2, xess, native (or none)" | tee -a "$log"
            return 1
            ;;
    esac

    if [[ ! "$resolution" =~ ^[0-9]+x[0-9]+$ ]]; then
        echo "Error: Invalid resolution '$resolution'. Expected WIDTHxHEIGHT (e.g., 2560x1440)." | tee -a "$log"
        return 1
    fi

    case "$quality_preset" in
        low|medium|high|ultra|custom)
            ;;
        *)
            echo "Error: Unsupported quality preset '$quality_preset'. Supported: low, medium, high, ultra, custom" | tee -a "$log"
            return 1
            ;;
    esac

    case "$ray_tracing" in
        off|on|psycho)
            ;;
        *)
            echo "Error: Unsupported ray tracing '$ray_tracing'. Supported: off, on, psycho" | tee -a "$log"
            return 1
            ;;
    esac

    case "$frame_generation" in
        off|on|auto)
            ;;
        *)
            echo "Error: Unsupported frame generation '$frame_generation'. Supported: off, on, auto" | tee -a "$log"
            return 1
            ;;
    esac

    launch_args_ref=(--resolution "$resolution")

    mkdir -p "$settings_dir"

    local -a profile_candidates=(
        "${profile_dir}/UserSettings.${mode}.${quality_preset}.rt-${ray_tracing}.fg-${frame_generation}.json"
        "${profile_dir}/UserSettings.${mode}.${quality_preset}.json"
        "${profile_dir}/UserSettings.${mode}.json"
        "${profile_dir}/UserSettings.default.json"
    )

    local selected_profile=""
    local candidate
    for candidate in "${profile_candidates[@]}"; do
        if [[ -f "$candidate" ]]; then
            selected_profile="$candidate"
            break
        fi
    done

    if [[ -n "$selected_profile" ]]; then
        cp "$selected_profile" "$target_settings_file"
        echo "Applied settings profile: $selected_profile" | tee -a "$log"
    else
        echo "Warning: No profile found in $profile_dir. Keeping current in-game settings." | tee -a "$log"
    fi

    echo "Applied settings => mode=$mode resolution=$resolution quality=$quality_preset ray_tracing=$ray_tracing frame_generation=$frame_generation" | tee -a "$log"
    return 0
}

# Check if Steam directory exists
if [[ ! -d "$STEAM_PATH" ]]; then
    echo "Error: Steam directory not found at $STEAM_PATH"
    exit 1
fi

# Function to launch with a specific upscaling mode
run_bench() {
    local mode=$1   # e.g., dlss, fsr2
    local res=$2    # resolution, e.g., 2560x1440
    local log=$3
    local quality_preset=${4:-high}
    local ray_tracing=${5:-off}
    local frame_generation=${6:-off}

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
    ally_setting "$mode" "$res" "$quality_preset" "$ray_tracing" "$frame_generation" "$log" launch_args || return 1

    
    SteamAppId=${GAME_ID} \
    SteamGameId=${GAME_ID} \
    PROTON_VERB="waitforexitandrun" \
    STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH" \
    STEAM_COMPAT_DATA_PATH="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID" \
    STEAM_RUNTIME=1 \
    PROTON_LOG=1 \
    VKD3D_FEATURE_LEVEL=12_0 \
    "$proton_path/proton" run \
    "$exe_path" \
        --launcher-skip \
        --intro-skip \
        "${launch_args[@]}" \
        -benchmark
            >>"$log" 2>&1
    
    local exit_code=$?
    if [[ $exit_code -eq 0 ]]; then
        echo "Benchmark completed successfully for $mode" | tee -a "$log"
    else
        echo "Benchmark failed for $mode (exit code: $exit_code)" | tee -a "$log"
    fi
    
    sleep 15   # give the game time to close cleanly
    return $exit_code
}

LOGFILE="${HOME}/cyberpunk_benchmark_$(date +%Y%m%d_%H%M%S).txt"
echo "Cyberpunk 2077 Upscaling Benchmark – $(date)" >"$LOGFILE"
echo "Steam Path: $STEAM_PATH" >>"$LOGFILE"
echo "Proton Version: $PROTON_VERSION" >>"$LOGFILE"
echo "=======================================" >>"$LOGFILE"

# Test different upscaling modes
# Note: DLSS requires RTX GPU, FSR works on any modern GPU

echo "Starting benchmark runs..."

# High quality modes (1440p)
# if run_bench "dlss" "2560x1440" "$LOGFILE"; then
#     echo "✓ DLSS Quality completed"
# else
#     echo "✗ DLSS Quality failed"
# fi

# No DLSS, low quality, no ray tracing, no frame generation, 1080p
if run_bench "native" "1920x1080" "$LOGFILE" "low" "off" "off"; then
    echo "✓ Native Low Quality completed"
else
    echo "✗ Native Low Quality failed"
fi

# if run_bench "fsr2" "2560x1440" "$LOGFILE"; then
#     echo "✓ FSR2 Quality completed"
# else
#     echo "✗ FSR2 Quality failed"
# fi

# # Performance modes (1080p)  
# if run_bench "dlss" "1920x1080" "$LOGFILE"; then
#     echo "✓ DLSS Performance completed"
# else
#     echo "✗ DLSS Performance failed"
# fi

# if run_bench "fsr2" "1920x1080" "$LOGFILE"; then
#     echo "✓ FSR2 Performance completed"
# else
#     echo "✗ FSR2 Performance failed"
# fi

echo ""
echo "Benchmark completed. Results saved to: $LOGFILE"
echo "You can view the results with: cat \"$LOGFILE\""