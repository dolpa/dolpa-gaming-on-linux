# Deus Ex: Mankind Divided benchmark test groups
# This file is sourced by run_deusex-md_benchmark.sh
# Required by caller: declare -A TEST_GROUPS

# Cross-resolution quality sweeps
TEST_GROUPS["quick"]="native-1080p-high native-1440p-high native-4k-high"
TEST_GROUPS["native-comparison"]="native-1080p-ultra native-1440p-ultra native-4k-ultra"

# Resolution-specific full sweeps
TEST_GROUPS["1080p-all"]="native-1080p-low native-1080p-medium native-1080p-high native-1080p-very-high native-1080p-ultra"
TEST_GROUPS["1440p-all"]="native-1440p-low native-1440p-medium native-1440p-high native-1440p-very-high native-1440p-ultra"
TEST_GROUPS["4k-all"]="native-4k-low native-4k-medium native-4k-high native-4k-very-high native-4k-ultra"

# Quality-specific cross-resolution sweeps
TEST_GROUPS["quality-low"]="native-1080p-low native-1440p-low native-4k-low"
TEST_GROUPS["quality-medium"]="native-1080p-medium native-1440p-medium native-4k-medium"
TEST_GROUPS["quality-high"]="native-1080p-high native-1440p-high native-4k-high"
TEST_GROUPS["quality-very-high"]="native-1080p-very-high native-1440p-very-high native-4k-very-high"
TEST_GROUPS["quality-ultra"]="native-1080p-ultra native-1440p-ultra native-4k-ultra"

# Keep existing quick-group naming convention used by the runner
TEST_GROUPS["4k-quick-low"]="native-4k-low"
TEST_GROUPS["4k-quick-medium"]="native-4k-medium"
TEST_GROUPS["4k-quick-high"]="native-4k-high"
TEST_GROUPS["4k-quick-very-high"]="native-4k-very-high"
TEST_GROUPS["4k-quick-ultra"]="native-4k-ultra"

TEST_GROUPS["quick-4k"]="native-4k-low native-4k-medium native-4k-high native-4k-very-high native-4k-ultra"
