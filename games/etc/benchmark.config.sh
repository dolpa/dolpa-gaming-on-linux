# Global configuration to congrol logging level and keep other assets for debug or other purposes
RUN_AUTOMATION_IN_PROD_MODE=false


# "Av" "TEST" "RS" "RS-TYPE" "RS-PRESET" "RESOLUTION" "QUALITY" "RT" "RT-PRESET" "FG"
# Resolution Scale (RS): "OFF" or "DLSS" (or "FSR21", "FRS3" and "XeSS" in other games)
# Resolution Scale Type (RST): for DLSS: "cnn" - convolution neural network,
#                                        "tm"  - transformer model (DLSS 3.5+)
# Resolution Scaling Settings / Presets (RS-PRESET): depends on the RS technology, but usually maps to in‑game presets or custom configs, e.g. for DLSS it can be "ultra performance", "performance", "quality", "ultra quality" (varies by game and RS technology, usually maps to in‑game presets, but can be used for custom configs as well)
#                       e.g. "auto",
#                            "nvidia dlaa",
#                            "quality",
#                            "performance", 
#                            "ultra performance"
# (varies by game and RS technology, usually maps to in‑game presets, but can be used for custom configs as well)
# Frame Generation (FG): "off", dlssx2, dlssx3, dlssx4, fsr31
# Resolution (RESOLUTION): e.g. "1080p" - 1920x1080, "1440p" - 2560x1440, "2160p" - 3840x2160
# Quality Preset (QUALITY): e.g. "low", "medium", "high", very-high, "ultra" (usually maps to in‑game presets, but can be used for custom configs as well)
# Ray Tracing (RT): "on" / "off" or "preset" (varies by game, usually maps to in‑game presets, but can be used for custom configs as well)
# Ray Tracing Preset (RT-PRESET): e.g. "na" in case TR is off and the RT-PRESET is not applicable, otherwise "path tracing", "sun", "local shadows", "reflections" or "all" (varies by game, usually maps to in‑game presets, but can be used for custom configs as well)

# Here the default definitions for the different parameters used in the test definitions (e.g. in games/ac-valhalla/benchmark/config/tests.conf.sh) are defined; you can customize these definitions for each game as needed, and you can also add more parameters if needed (e.g. for specific graphics settings or benchmark modes that are relevant for a specific game) 

#DirectX Version (DX): "dx11" or "dx12"
declare -A GAME_DIRECTX_VERSIONS
GAME_DIRECTX_VERSIONS=(
    ["dx11"]="dx11"           # DirectX 11
    ["dx12"]="dx12"           # DirectX 12
)

# Resolution Scale (RS): "OFF" or "DLSS" (or "FSR21", "FRS3" and "XeSS" in other games)
declare -A RESOLUTION_SCALE
GAME_RESOLUTION_SCALE=(
    ["OFF"]="off"               # No resolution scaling
    ["DLSS"]="dlss"             # NVIDIA DLSS (Deep Learning Super Sampling)
    ["FSR21"]="fsr21"           # AMD FidelityFX Super Resolution 2.1
    ["FRS3"]="frs3"             # Intel Frame Rate Scaling 3
    ["XeSS"]="xess"             # Intel Xe Super Sampling
)

# Ray Tracing (RT): "on" / "off" or "preset" (varies by game, usually maps to in‑game presets, but can be used for custom configs as well)
declare -A GAME_RESOLUTION_SCALE_TYPES
GAME_RESOLUTION_SCALE_TYPES=(
    ["cnn"]="cnn"               # Convolutional Neural Network (DLSS)
    ["tm"]="tm"                 # Transformer Model (DLSS 3.5+)
    ["na"]="na"                 # Not applicable (for resolution scales that don't have types, e.g. OFF)
)

# Resolution Scaling Settings / Presets (RS-PRESET): depends on the RS technology
declare -A GAME_RESOLUTION_SCALE_PRESETS
GAME_RESOLUTION_SCALE_PRESETS=(
    ["ultra_performance"]="ultra_performance"   # Ultra Performance preset (example for DLSS)
    ["performance"]="performance"               # Performance preset (example for DLSS)
    ["quality"]="quality"                       # Quality preset (example for DLSS)
    ["ultra_quality"]="ultra_quality"           # Ultra Quality preset (example for DLSS)
    ["auto"]="auto"                             # Auto preset (example for custom resolution scaling settings)
    ["nvidia_dlaa"]="nvidia_dlaa"               # NVIDIA DLAA (Deep Learning Anti-Aliasing) preset
)


# Screen Resolution definitions
declare -A GAME_RESOLUTIONS
GAME_RESOLUTIONS=(
    ["1080p"]="1920x1080"
    ["1440p"]="2560x1440"
    ["2160p"]="3840x2160"
)

# Frame Generation (FG): "off", dlssx2, dlssx3, dlssx4, fsr31
declare -A GAME_FRAME_GENERATION
GAME_FRAME_GENERATION=(
    ["off"]="off"             # Frame Generation off
    ["dlssx2"]="dlssx2"       # DLSS Frame Generation x2
    ["dlssx3"]="dlssx3"       # DLSS Frame Generation x3
    ["dlssx4"]="dlssx4"       # DLSS Frame Generation x4
    ["fsr31"]="fsr31"         # FSR 3.1 Frame Generation
)

# Game quality presets (QUALITY): e.g. "low", "medium", "high", very-high, "ultra" (usually maps to in‑game presets, but can be used for custom configs as well)
declare -A GAME_QUALITY_PRESETS
GAME_QUALITY_PRESETS=(
    ["low"]="low"             # Low quality preset
    ["medium"]="medium"       # Medium quality preset
    ["high"]="high"           # High quality preset 
    ["very_high"]="very_high" # Very High quality preset
    ["ultra"]="ultra"         # Ultra quality preset
)

# Ray Tracing (RT): "on" / "off" or "preset" (varies by game, usually maps to in‑game presets, but can be used for custom configs as well)
declare -A GAME_RAY_TRACING
GAME_RAY_TRACING=(
    ["off"]="off"             # Ray Tracing off
    ["on"]="on"               # Ray Tracing on (if the game doesn't have specific RT presets, otherwise you can use the specific presets instead of "on")
    ["preset"]="preset"       # Ray Tracing preset (if the game has specific RT presets, otherwise you can use "on" instead of "preset")
)

# Game Ray Tracing Presets (RT-PRESET): e.g. "na" in case TR is off and the RT-PRESET is not applicable, otherwise "path tracing", "sun", "local shadows", "reflections" or "all" (varies by game, usually maps to in‑game presets, but can be used for custom configs as well)
declare -A GAME_RAY_TRACING_PRESETS
GAME_RAY_TRACING_PRESETS=(
    ["na"]="na"                       # Not applicable (for cases where Ray Tracing is off)
    ["path_tracing"]="path_tracing"   # Path Tracing preset
    ["sun"]="sun"                     # Sun Ray Tracing preset
    ["local_shadows"]="local_shadows" # Local Shadows Ray Tracing preset
    ["reflections"]="reflections"     # Reflections Ray Tracing preset
    ["all"]="all"                     # All Ray Tracing features preset
)