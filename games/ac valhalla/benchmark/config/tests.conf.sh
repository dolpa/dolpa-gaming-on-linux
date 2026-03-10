# Metro Exodus benchmark test definitions
# This file is sourced by run_metro_exodus_benchmark.sh
# Required by caller: declare -A TESTS
# Format: TESTS["test-name"]="RS RST RS-PRESET RESOLUTION QUALITY RT RT-PRESET FG"

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

# 1080p dlss tests
TESTS["dlss_cnn_ultra-perf_1080p_medium_rt-off_na_fg-off"]="dlss cnn ultra-perf 1080p medium off na off"   # DLSS, Ultra Performance mode, 1080p, Medium settings, Ray Tracing off, Ray Tracing Preset off, Frame Generation off (Transformer)
TESTS["dlss_cnn_ultra-perf_1440p_medium_rt-off_na_fg-off"]="dlss cnn ultra-perf 1440p medium off na off"   # DLSS, Ultra Performance mode, 1440p, Medium settings, Ray Tracing off, Ray Tracing Preset off, Frame Generation off (Transformer)
TESTS["dlss_cnn_ultra-perf_2160p_medium_rt-off_na_fg-off"]="dlss cnn ultra-perf 2160p medium off na off"   # DLSS, Ultra Performance mode, 2160p, Medium settings, Ray Tracing off, Ray Tracing Preset off, Frame Generation off (Transformer)