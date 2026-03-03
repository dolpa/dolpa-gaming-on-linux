# Metro Exodus benchmark test groups
# This file is sourced by run_metro_exodus_benchmark.sh
# Required by caller: declare -A TEST_GROUPS

TEST_GROUPS["native-quick"]="native-1080p-high-rt-off native-1440p-high-rt-off native-4k-high-rt-off"
TEST_GROUPS["native-comparison"]="native-1080p-high-rt-off native-1440p-high-rt-off native-4k-high-rt-off"
TEST_GROUPS["native-1080p-scaling"]="native-1080p-low-rt-off native-1080p-medium-rt-off native-1080p-high-rt-off native-1080p-ultra-rt-off"
TEST_GROUPS["native-1440p-scaling"]="native-1440p-low-rt-off native-1440p-medium-rt-off native-1440p-high-rt-off native-1440p-ultra-rt-off"
TEST_GROUPS["native-4k-scaling"]="native-4k-low-rt-off native-4k-medium-rt-off native-4k-high-rt-off native-4k-ultra-rt-off"
TEST_GROUPS["all-native"]="native-1080p-low-rt-off native-1080p-medium-rt-off native-1080p-high-rt-off native-1080p-ultra-rt-off native-1440p-low-rt-off native-1440p-medium-rt-off native-1440p-high-rt-off native-1440p-ultra-rt-off native-4k-low-rt-off native-4k-medium-rt-off native-4k-high-rt-off native-4k-ultra-rt-off"
