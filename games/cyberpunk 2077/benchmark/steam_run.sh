#!/usr/bin/env bash
# -------------------------------------------------
# Cyberpunk 2077 DLSS/FSR Benchmark on Ubuntu (Steam)
# -------------------------------------------------
GAME_ID=1091500                                     # Steam AppID for Cyberpunk 2077
STEAM_PATH="${HOME}/.local/share/Steam"             # Main Steam installation
STEAM_ROOT="${HOME}/.steam/root"
CUSTOM_LIBRARY_PATH="/mnt/OldData/Steam Library"    # Custom Steam library path
PROTON_VERSION="GE-Proton9-27"                      # Adjust version as needed

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

    echo "=== Running with $mode upscaling at $res ===" | tee -a "$log"
    
    # Set up environment
    export STEAM_COMPAT_DATA_PATH="$STEAM_PATH/steamapps/compatdata/$GAME_ID"
    export STEAM_COMPAT_CLIENT_INSTALL_PATH="$STEAM_PATH"
    
    STEAM_RUNTIME=1 \
    PROTON_NO_ESYNC=1 \
    PROTON_USE_WINED3D=0 \
    PROTON_USE_D9VK=0 \
    PROTON_USE_DXVK=1 \
    PROTON_ENABLE_NVAPI=1 \
    PROTON_LOG=1 \
    "$proton_path/proton" run \
        "$exe_path" \
        --launcher-skip --intro-skip --resolution "$res" \
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
if run_bench "dlss" "2560x1440" "$LOGFILE"; then
    echo "✓ DLSS Quality completed"
else
    echo "✗ DLSS Quality failed"
fi

if run_bench "fsr2" "2560x1440" "$LOGFILE"; then
    echo "✓ FSR2 Quality completed"
else
    echo "✗ FSR2 Quality failed"
fi

# Performance modes (1080p)  
if run_bench "dlss" "1920x1080" "$LOGFILE"; then
    echo "✓ DLSS Performance completed"
else
    echo "✗ DLSS Performance failed"
fi

if run_bench "fsr2" "1920x1080" "$LOGFILE"; then
    echo "✓ FSR2 Performance completed"
else
    echo "✗ FSR2 Performance failed"
fi

echo ""
echo "Benchmark completed. Results saved to: $LOGFILE"
echo "You can view the results with: cat \"$LOGFILE\""