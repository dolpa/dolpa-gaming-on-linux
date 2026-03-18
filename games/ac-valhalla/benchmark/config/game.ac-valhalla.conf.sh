

# Game/Steam identifiers
GAME_ID=2208920                             # Steam AppID for Assassin’s Creed Valhalla
GAME_NAME="Assassin's Creed Valhalla"       # Human‑friendly game name (used for logging, folder names, …)
GAME_EXE_PATH=""                            # Relative path to the game executable from the game root folder (used to locate the executable for launching)
GAME_EXE="ACValhalla.exe"                   # Game executable name (used to locate the executable for launching)
GAME_CREATOR_STUDIO="Ubisoft"               # Creator studio name (used for folder paths in the user settings and benchmark results)
GAME_LAUNCH_ARGS="-uplay_steam_mode -benchmark -skipStartScreen"
                                            # Game launcher name (used for folder paths in the user settings and benchmark results)

GAME_PROTON_VERSION="GE-Proton10-32"

USER_SETTINGS_FOLDER="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID/pfx/drive_c/users/steamuser/Documents/${GAME_NAME}/"
BENCHMARK_RESULTS_SOURCE_DIR="$CUSTOM_LIBRARY_PATH/steamapps/compatdata/$GAME_ID/pfx/drive_c/users/steamuser/Documents/${GAME_CREATOR_STUDIO}${GAME_NAME}/benchmarkResults/"
GAME_PROFILE_EXTENSION="ini"
USER_SETTINGS_FILE="${USER_SETTINGS_FOLDER}/ACValhalla.${GAME_PROFILE_EXTENSION}"   # Path to the user settings file that will be modified by the benchmark script to apply different configurations for each test; this should be the actual file used by the game to read user settings (e.g. graphics settings, controls, …) when the game is launched, so that modifying this file will change the game settings for the benchmark tests
USER_CONFIG_FILENAME="ACValhalla"           # Base name for the User Settings files inside the installation directories (without the extention)
NEED_CD_TO_GAME_DIR_BEFORE_LAUNCH = false   # Whether the benchmark script needs to change the current directory to the game directory before launching the game (some games require this for correct loading of assets, configs, …)

RUN_AUTOMATION_IN_PROD_MODE=false           # Whether to run the benchmark automation in production mode (true) or in testing mode (false)

# Benchmark configuration
NEED_TO_CLOCK_BENCHMARK_IN_MENU=true
NEED_TO_TAKE_SCREENSHOT_OF_RESULTS=true

# results position in the screenshots (offset from the top left corner of the screen, in pixels; WIDTH and HEIGHT of the area to crop for OCR)
BENCHMARK_SCREENSHOT_RESULTS_W=
BENCHMARK_SCREENSHOT_RESULTS_H=
BENCHMARK_SCREENSHOT_RESULTS_X_OFFSET=
BENCHMARK_SCREENSHOT_RESULTS_Y_OFFSET=
                    # Delay in seconds before taking a screenshot of the benchmark results (to ensure that the results are fully displayed on the screen)

# Number of tests to run on same profile (will be implemented later, currently the benchmark will be run only once per profile)
GAME_BENCHMARK_RUNS=1

# Array of environment variables to set when running the benchmark; you can add any environment variables needed for the game or Proton here, e.g. to enable specific Proton features, set up logging, etc.

# VKD3D_FEATURE_LEVEL=12_2 PROTON_HIDE_NVIDIA_GPU=0 PROTON_ENABLE_NVAPI=1 VKD3D_CONFIG=dxr12 DXVK_ASYNC=1 

declare -A RUN_ENVIRONMENT_VARIABLES
RUN_ENVIRONMENT_VARIABLES=(
    ["VKD3D_FEATURE_LEVEL"]="12_2"
    ["PROTON_HIDE_NVIDIA_GPU"]="0"
    ["PROTON_ENABLE_NVAPI"]="1"
    ["VKD3D_CONFIG"]="dxr12"
    ["DXVK_ASYNC"]="1"
)

# This should be the name of a custom function that you can define in this game config file to extract benchmark results from screenshots for CUSTOM (ANY other) game if this variable is not set or the function is not defined, the default extraction function (extract_benchmark_results_from_screenshots_to_results) will be used, which you can also customize if needed
# CUSTOM_EXTRACT_BENCHMARK_RESULTS_FROM_SCREENSHOTS_FUNCTION="custom_extract_benchmark_results_from_screenshots_ac_valhalla"

# Custom function to extract benchmark results from screenshots; you can implement this function to extract the relevant information from the screenshots taken during the benchmark run and save it in a structured format (e.g. CSV) for later analysis; you can adapt it to how the benchmark results are displayed in the screenshots and what specific information you want to extract (e.g. average FPS, frametimes, …)
# $results_folder - this variable is available in this function and points to the folder where the benchmark results and screenshots are saved for the current benchmark run
# $SHORT_GAME_NAME - this variable is available in this function and contains a short version of the game name that can be used in file names (e.g. "ac-valhalla" for "Assassin’s Creed Valhalla")
# $script_run_timestamp - this variable is available in this function and contains the timestamp of when the benchmark script was run, which can be used in file names to ensure uniqueness (e.g. "2024-06-01_12-00-00")
# $GAME_NAME - this variable is available in this function and contains the full game name (e.g. "Assassin’s Creed Valhalla") that can be used for logging or other purposes
function custom_extract_benchmark_results_from_screenshots_ac_valhalla() {
    log_info "TODO: implement this function to extract benchmark results from screenshots for ${GAME_NAME}; you can adapt it to how the benchmark results are displayed in the screenshots and what specific information you want to extract (e.g. average FPS, frametimes, …)"
    # try each screenshot taken during the benchmark run and extract the relevant information using OCR or other methods; you can use tools like tesseract‑ocr for OCR, or if the game provides an API or a way to export the results in a structured format, you can use that instead
    for i in $(seq 1 "$_NUMBER_OF_SCREENSHOTS"); do
        local screenshot_path="${results_folder}/screenshot_${SHORT_GAME_NAME}_${script_run_timestamp}_${i}.png"
        log_info "Extracting benchmark results from screenshot: $screenshot_path"
        if [[ -f "$screenshot_path" ]]; then
            echo "TODO: implement the logic to extract benchmark results from the screenshot: $screenshot_path"
            # Implement the logic to extract benchmark results from the screenshot
            # For example, you can use OCR tools like tesseract-ocr to extract text from the screenshot
            # and then parse the text to get the relevant benchmark metrics (e.g., average FPS, frametimes, etc.)
        fi
    done
}