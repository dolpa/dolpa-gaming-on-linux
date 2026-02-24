# Cyberpunk 2077 benchmark test groups
# This file is sourced by run_cp2077_benchmark.sh
# Required by caller: declare -A TEST_GROUPS

TEST_GROUPS["quick"]="native-1080p-high-rt-off dlss-quality-1440p-high-rt-off fsr2-quality-1440p-high-rt-off"
TEST_GROUPS["native-comparison"]="native-1080p-high-rt-off native-1440p-high-rt-off native-4k-high-rt-off"
TEST_GROUPS["dlss-comparison"]="dlss-quality-1440p-high-rt-off dlss-balanced-1440p-high-rt-off dlss-performance-1440p-high-rt-off"
TEST_GROUPS["fsr-comparison"]="fsr2-quality-1440p-high-rt-off fsr21-quality-1440p-high-rt-off fsr3-quality-1440p-high-rt-off"
TEST_GROUPS["rt-comparison"]="native-1440p-high-rt-off native-1440p-high-rt-on dlss-quality-1440p-high-rt-on"
TEST_GROUPS["4k-performance"]="native-4k-high-rt-off dlss-quality-4k-high-rt-off dlss-performance-4k-high-rt-off fsr3-quality-4k-high-rt-off"
TEST_GROUPS["quick-4k"]="native-4k-high-rt-off dlss-quality-4k-high-rt-off dlss-performance-4k-high-rt-off fsr3-quality-4k-high-rt-off fsr3-performance-4k-high-rt-off dlss-quality-4k-high-rt-on"
TEST_GROUPS["4k-quick-low"]="native-4k-low-rt-off dlss-ultra-performance-4k-low-rt-off fsr2-performance-4k-low-rt-off fsr3-performance-4k-low-rt-off"
TEST_GROUPS["4k-quick-medium"]="native-4k-medium-rt-off dlss-ultra-performance-4k-medium-rt-off fsr2-performance-4k-medium-rt-off fsr3-performance-4k-medium-rt-off"
TEST_GROUPS["4k-quick-high"]="native-4k-high-rt-off dlss-quality-4k-high-rt-off dlss-performance-4k-high-rt-off fsr2-performance-4k-high-rt-off fsr3-performance-4k-high-rt-off"
TEST_GROUPS["4k-quick-ultra"]="native-4k-ultra-rt-off dlss-quality-4k-ultra-rt-off dlss-ultra-performance-4k-ultra-rt-off fsr2-performance-4k-ultra-rt-off fsr3-performance-4k-ultra-rt-off"
