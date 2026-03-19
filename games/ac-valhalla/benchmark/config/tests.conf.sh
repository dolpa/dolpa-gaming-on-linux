# AC Valhalla benchmark test definitions
# This file is sourced by run_ac-valhalla_benchmark.sh
# Required by caller: declare -A TESTS
# Format: TESTS["test-name"]="DX RS RST RS-PRESET RESOLUTION QUALITY RT RT-PRESET FG"

# DirectX Version (DX): "dx11" or "dx12"
# Resolution Scale (RS): "OFF" or "DLSS" (or "FSR21", "FRS3" and "XeSS" in other games)
# Resolution Scale Type (RST): for DLSS: "cnn" - convolution neural network, 
#                                        "tm"  - transformer model (DLSS 3.5+)
#                                        "na" - not applicable (e.g. for RS technologies that don't have different types or when RS is off)
# Resolution Scaling Settings / Presets (RS-PRESET): depends on the RS technology, but usually maps to in‑game presets or custom configs, e.g. for DLSS it can be "ultra performance", "performance", "quality", "ultra quality"
# Resolution (RESOLUTION): e.g. "1080p" - 1920x1080, "1440p" - 2560x1440, "2160p" - 3840x2160
# Quality Preset (QUALITY): e.g. "low", "medium", "high", "very-high", "ultra" (usually maps to in‑game presets)
# Ray Tracing (RT): "on" / "off" or preset name
# Ray Tracing Preset (RT-PRESET): e.g. "na" when RT is off, otherwise various options like "shadows", "reflections", "all"
# Frame Generation (FG): "off", "dlssx2", "dlssx3", "dlssx4", "fsr31"

# Native tests (no upscaling)
TESTS["native-1080p-low-rt-off"]="dx12 off na na 1080p low off na off"
TESTS["native-1080p-medium-rt-off"]="dx12 off na na 1080p medium off na off"
TESTS["native-1080p-high-rt-off"]="dx12 off na na 1080p high off na off"
TESTS["native-1080p-ultra-rt-off"]="dx12 off na na 1080p ultra off na off"

TESTS["native-1440p-low-rt-off"]="dx12 off na na 1440p low off na off"
TESTS["native-1440p-medium-rt-off"]="dx12 off na na 1440p medium off na off"
TESTS["native-1440p-high-rt-off"]="dx12 off na na 1440p high off na off"
TESTS["native-1440p-ultra-rt-off"]="dx12 off na na 1440p ultra off na off"

TESTS["native-4k-low-rt-off"]="dx12 off na na 2160p low off na off"
TESTS["native-4k-medium-rt-off"]="dx12 off na na 2160p medium off na off"
TESTS["native-4k-high-rt-off"]="dx12 off na na 2160p high off na off"
TESTS["native-4k-ultra-rt-off"]="dx12 off na na 2160p ultra off na off"

# DLSS tests
TESTS["dlss-performance-1080p-high-rt-off"]="dx12 dlss cnn performance 1080p high off na off"
TESTS["dlss-quality-1080p-high-rt-off"]="dx12 dlss cnn quality 1080p high off na off"

TESTS["dlss-performance-1440p-high-rt-off"]="dx12 dlss cnn performance 1440p high off na off"
TESTS["dlss-quality-1440p-high-rt-off"]="dx12 dlss cnn quality 1440p high off na off"

TESTS["dlss-performance-4k-high-rt-off"]="dx12 dlss cnn performance 2160p high off na off"
TESTS["dlss-quality-4k-high-rt-off"]="dx12 dlss cnn quality 2160p high off na off"
TESTS["dlss-ultra-performance-4k-high-rt-off"]="dx12 dlss cnn ultra-performance 2160p high off na off"