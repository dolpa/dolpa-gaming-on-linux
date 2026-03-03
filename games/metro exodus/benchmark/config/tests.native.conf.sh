# Metro Exodus benchmark test definitions
# This file is sourced by run_metro_exodus_benchmark.sh
# Required by caller: declare -A TESTS
# Format: TESTS["test-name"]="mode resolution quality ray_tracing frame_generation"

# Native Linux relevant tests only.
# Ray tracing, DLSS/FSR, and frame generation are intentionally excluded.

# 1080p native tests
TESTS["native-1080p-low-rt-off"]="native 1920x1080 low off off"
TESTS["native-1080p-medium-rt-off"]="native 1920x1080 medium off off"
TESTS["native-1080p-high-rt-off"]="native 1920x1080 high off off"
TESTS["native-1080p-ultra-rt-off"]="native 1920x1080 ultra off off"

# 1440p native tests
TESTS["native-1440p-low-rt-off"]="native 2560x1440 low off off"
TESTS["native-1440p-medium-rt-off"]="native 2560x1440 medium off off"
TESTS["native-1440p-high-rt-off"]="native 2560x1440 high off off"
TESTS["native-1440p-ultra-rt-off"]="native 2560x1440 ultra off off"

# 4K native tests
TESTS["native-4k-low-rt-off"]="native 3840x2160 low off off"
TESTS["native-4k-medium-rt-off"]="native 3840x2160 medium off off"
TESTS["native-4k-high-rt-off"]="native 3840x2160 high off off"
TESTS["native-4k-ultra-rt-off"]="native 3840x2160 ultra off off"
