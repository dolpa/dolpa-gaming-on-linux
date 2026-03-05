# Deus Ex: Mankind Divided benchmark test definitions
# This file is sourced by run_deusex-md_benchmark.sh
# Required by caller: declare -A TESTS
# Format: TESTS["test-name"]="mode resolution quality ray_tracing frame_generation"

# Native rendering tests - 3 resolutions x 5 quality presets

# 1080p
TESTS["native-1080p-low"]="native 1920x1080 low off off"
TESTS["native-1080p-medium"]="native 1920x1080 medium off off"
TESTS["native-1080p-high"]="native 1920x1080 high off off"
TESTS["native-1080p-very-high"]="native 1920x1080 very-high off off"
TESTS["native-1080p-ultra"]="native 1920x1080 ultra off off"

# 1440p
TESTS["native-1440p-low"]="native 2560x1440 low off off"
TESTS["native-1440p-medium"]="native 2560x1440 medium off off"
TESTS["native-1440p-high"]="native 2560x1440 high off off"
TESTS["native-1440p-very-high"]="native 2560x1440 very-high off off"
TESTS["native-1440p-ultra"]="native 2560x1440 ultra off off"

# 4k
TESTS["native-4k-low"]="native 3840x2160 low off off"
TESTS["native-4k-medium"]="native 3840x2160 medium off off"
TESTS["native-4k-high"]="native 3840x2160 high off off"
TESTS["native-4k-very-high"]="native 3840x2160 very-high off off"
TESTS["native-4k-ultra"]="native 3840x2160 ultra off off"

# Proton rendering tests - 3 resolutions x 5 quality presets

# 1080p
TESTS["proton-1080p-low"]="proton 1920x1080 low off off"
TESTS["proton-1080p-medium"]="proton 1920x1080 medium off off"
TESTS["proton-1080p-high"]="proton 1920x1080 high off off"
TESTS["proton-1080p-very-high"]="proton 1920x1080 very-high off off"
TESTS["proton-1080p-ultra"]="proton 1920x1080 ultra off off"

# 1440p
TESTS["proton-1440p-low"]="proton 2560x1440 low off off"
TESTS["proton-1440p-medium"]="proton 2560x1440 medium off off"
TESTS["proton-1440p-high"]="proton 2560x1440 high off off"
TESTS["proton-1440p-very-high"]="proton 2560x1440 very-high off off"
TESTS["proton-1440p-ultra"]="proton 2560x1440 ultra off off"

# 4k
TESTS["proton-4k-low"]="proton 3840x2160 low off off"
TESTS["proton-4k-medium"]="proton 3840x2160 medium off off"
TESTS["proton-4k-high"]="proton 3840x2160 high off off"
TESTS["proton-4k-very-high"]="proton 3840x2160 very-high off off"
TESTS["proton-4k-ultra"]="proton 3840x2160 ultra off off"