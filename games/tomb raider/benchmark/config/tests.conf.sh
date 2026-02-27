# Tomb Raider benchmark test definitions
# This file is sourced by run_tomb_raider_benchmark.sh
# Required by caller: declare -A TESTS
# Format: TESTS["test-name"]="mode resolution quality ray_tracing frame_generation"

# Native rendering tests - All resolutions and quality combinations

# 1080p Native tests
TESTS["native-1080p-low-rt-off"]="native 1920x1080 low off off"                 # Native 1080p Low settings, Ray Tracing off, Frame Generation off
TESTS["native-1080p-medium-rt-off"]="native 1920x1080 medium off off"           # Native 1080p Medium settings, Ray Tracing off, Frame Generation off
TESTS["native-1080p-high-rt-off"]="native 1920x1080 high off off"               # Native 1080p High settings, Ray Tracing off, Frame Generation off
TESTS["native-1080p-ultra-rt-off"]="native 1920x1080 ultra off off"             # Native 1080p Ultra settings, Ray Tracing off, Frame Generation off
TESTS["native-1080p-low-rt-on"]="native 1920x1080 low on off"                   # Native 1080p Low settings, Ray Tracing on, Frame Generation off
TESTS["native-1080p-medium-rt-on"]="native 1920x1080 medium on off"             # Native 1080p Medium settings, Ray Tracing on, Frame Generation off
TESTS["native-1080p-high-rt-on"]="native 1920x1080 high on off"                 # Native 1080p High settings, Ray Tracing on, Frame Generation off
TESTS["native-1080p-ultra-rt-on"]="native 1920x1080 ultra on off"               # Native 1080p Ultra settings, Ray Tracing on, Frame Generation off

# 1440p Native tests
TESTS["native-1440p-low-rt-off"]="native 2560x1440 low off off"                 # Native 1440p Low settings, Ray Tracing off, Frame Generation off
TESTS["native-1440p-medium-rt-off"]="native 2560x1440 medium off off"           # Native 1440p Medium settings, Ray Tracing off, Frame Generation off
TESTS["native-1440p-high-rt-off"]="native 2560x1440 high off off"               # Native 1440p High settings, Ray Tracing off, Frame Generation off
TESTS["native-1440p-ultra-rt-off"]="native 2560x1440 ultra off off"             # Native 1440p Ultra settings, Ray Tracing off, Frame Generation off
TESTS["native-1440p-low-rt-on"]="native 2560x1440 low on off"                   # Native 1440p Low settings, Ray Tracing on, Frame Generation off
TESTS["native-1440p-medium-rt-on"]="native 2560x1440 medium on off"             # Native 1440p Medium settings, Ray Tracing on, Frame Generation off
TESTS["native-1440p-high-rt-on"]="native 2560x1440 high on off"                 # Native 1440p High settings, Ray Tracing on, Frame Generation off
TESTS["native-1440p-ultra-rt-on"]="native 2560x1440 ultra on off"               # Native 1440p Ultra settings, Ray Tracing on, Frame Generation off

# 4K Native tests
TESTS["native-4k-low-rt-off"]="native 3840x2160 low off off"                     # Native 4K Low settings, Ray Tracing off, Frame Generation off
TESTS["native-4k-medium-rt-off"]="native 3840x2160 medium off off"               # Native 4K Medium settings, Ray Tracing off, Frame Generation off
TESTS["native-4k-high-rt-off"]="native 3840x2160 high off off"                   # Native 4K High settings, Ray Tracing off, Frame Generation off
TESTS["native-4k-ultra-rt-off"]="native 3840x2160 ultra off off"                 # Native 4K Ultra settings, Ray Tracing off, Frame Generation off
TESTS["native-4k-low-rt-on"]="native 3840x2160 low on off"                       # Native 4K Low settings, Ray Tracing on, Frame Generation off
TESTS["native-4k-medium-rt-on"]="native 3840x2160 medium on off"                 # Native 4K Medium settings, Ray Tracing on, Frame Generation off
TESTS["native-4k-high-rt-on"]="native 3840x2160 high on off"                     # Native 4K High settings, Ray Tracing on, Frame Generation off
TESTS["native-4k-ultra-rt-on"]="native 3840x2160 ultra on off"

# DLSS tests - Quality modes: dlss-quality, dlss-balanced, dlss-performance, dlss-ultra-performance
# 1080p DLSS tests
TESTS["dlss-quality-1080p-low-rt-off"]="dlss-quality 1920x1080 low off off"         # DLSS Quality mode, 1080p, Low settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1080p-medium-rt-off"]="dlss-quality 1920x1080 medium off off"   # DLSS Quality mode, 1080p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1080p-high-rt-off"]="dlss-quality 1920x1080 high off off"       # DLSS Quality mode, 1080p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1080p-ultra-rt-off"]="dlss-quality 1920x1080 ultra off off"     # DLSS Quality mode, 1080p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1080p-low-rt-on"]="dlss-quality 1920x1080 low on off"           # DLSS Quality mode, 1080p, Low settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-1080p-medium-rt-on"]="dlss-quality 1920x1080 medium on off"     # DLSS Quality mode, 1080p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-1080p-high-rt-on"]="dlss-quality 1920x1080 high on off"         # DLSS Quality mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-1080p-ultra-rt-on"]="dlss-quality 1920x1080 ultra on off"       # DLSS Quality mode, 1080p, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["dlss-balanced-1080p-high-rt-off"]="dlss-balanced 1920x1080 high off off"     # DLSS Balanced mode, 1080p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-balanced-1080p-high-rt-on"]="dlss-balanced 1920x1080 high on off"       # DLSS Balanced mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-performance-1080p-high-rt-off"]="dlss-performance 1920x1080 high off off" # DLSS Performance mode, 1080p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-performance-1080p-high-rt-on"]="dlss-performance 1920x1080 high on off"   # DLSS Performance mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1080p-low-rt-off"]="dlss-ultra-performance 1920x1080 low off off" # DLSS Ultra Performance mode, 1080p, Low settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1080p-low-rt-off-transformer"]="dlss-ultra-performance 1920x1080 low off off" # DLSS Ultra Performance mode, 1080p, Low settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-low-rt-off-cnn"]="dlss-ultra-performance 1920x1080 low off off" # DLSS Ultra Performance mode, 1080p, Low settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-medium-rt-off"]="dlss-ultra-performance 1920x1080 medium off off"   # DLSS Ultra Performance mode, 1080p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1080p-medium-rt-off-transformer"]="dlss-ultra-performance 1920x1080 medium off off"   # DLSS Ultra Performance mode, 1080p, Medium settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-medium-rt-off-cnn"]="dlss-ultra-performance 1920x1080 medium off off"       # DLSS Ultra Performance mode, 1080p, Medium settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-high-rt-off"]="dlss-ultra-performance 1920x1080 high off off"       # DLSS Ultra Performance mode, 1080p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1080p-high-rt-off-transformer"]="dlss-ultra-performance 1920x1080 high off off"       # DLSS Ultra Performance mode, 1080p, High settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-high-rt-off-cnn"]="dlss-ultra-performance 1920x1080 high off off"    # DLSS Ultra Performance mode, 1080p, High settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-ultra-rt-off"]="dlss-ultra-performance 1920x1080 ultra off off"      # DLSS Ultra Performance mode, 1080p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1080p-ultra-rt-off-transformer"]="dlss-ultra-performance 1920x1080 ultra off off"     # DLSS Ultra Performance mode, 1080p, Ultra settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-ultra-rt-off-cnn"]="dlss-ultra-performance 1920x1080 ultra off off"       # DLSS Ultra Performance mode, 1080p, Ultra settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-low-rt-on"]="dlss-ultra-performance 1920x1080 low on off"    # DLSS Ultra Performance mode, 1080p, Low settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1080p-low-rt-on-transformer"]="dlss-ultra-performance 1920x1080 low on off"   # DLSS Ultra Performance mode, 1080p, Low settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-low-rt-on-cnn"]="dlss-ultra-performance 1920x1080 low on off"   # DLSS Ultra Performance mode, 1080p, Low settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-medium-rt-on"]="dlss-ultra-performance 1920x1080 medium on off"   # DLSS Ultra Performance mode, 1080p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1080p-medium-rt-on-transformer"]="dlss-ultra-performance 1920x1080 medium on off"   # DLSS Ultra Performance mode, 1080p, Medium settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-medium-rt-on-cnn"]="dlss-ultra-performance 1920x1080 medium on off"   # DLSS Ultra Performance mode, 1080p, Medium settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-high-rt-on"]="dlss-ultra-performance 1920x1080 high on off"   # DLSS Ultra Performance mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1080p-high-rt-on-transformer"]="dlss-ultra-performance 1920x1080 high on off"  # DLSS Ultra Performance mode, 1080p, High settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-high-rt-on-cnn"]="dlss-ultra-performance 1920x1080 high on off"     # DLSS Ultra Performance mode, 1080p, High settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1080p-ultra-rt-on"]="dlss-ultra-performance 1920x1080 ultra on off"       # DLSS Ultra Performance mode, 1080p, Ultra settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1080p-ultra-rt-on-transformer"]="dlss-ultra-performance 1920x1080 ultra on off"   # DLSS Ultra Performance mode, 1080p, Ultra settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1080p-ultra-rt-on-cnn"]="dlss-ultra-performance 1920x1080 ultra on off"       # DLSS Ultra Performance mode, 1080p, Ultra settings, Ray Tracing on, Frame Generation off (CNN)

# 1440p DLSS tests
TESTS["dlss-quality-1440p-low-rt-off"]="dlss-quality 2560x1440 low off off"             # DLSS Quality mode, 1440p, Low settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1440p-medium-rt-off"]="dlss-quality 2560x1440 medium off off"       # DLSS Quality mode, 1440p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1440p-high-rt-off"]="dlss-quality 2560x1440 high off off"           # DLSS Quality mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1440p-ultra-rt-off"]="dlss-quality 2560x1440 ultra off off"         # DLSS Quality mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-1440p-low-rt-on"]="dlss-quality 2560x1440 low on off"               # DLSS Quality mode, 1440p, Low settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-1440p-medium-rt-on"]="dlss-quality 2560x1440 medium on off"         # DLSS Quality mode, 1440p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-1440p-high-rt-on"]="dlss-quality 2560x1440 high on off"             # DLSS Quality mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-1440p-ultra-rt-on"]="dlss-quality 2560x1440 ultra on off"           # DLSS Quality mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["dlss-balanced-1440p-high-rt-off"]="dlss-balanced 2560x1440 high off off"     # DLSS Balanced mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-balanced-1440p-high-rt-on"]="dlss-balanced 2560x1440 high on off"       # DLSS Balanced mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-performance-1440p-high-rt-off"]="dlss-performance 2560x1440 high off off"   # DLSS Performance mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-performance-1440p-high-rt-on"]="dlss-performance 2560x1440 high on off"     # DLSS Performance mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1440p-low-rt-off"]="dlss-ultra-performance 2560x1440 low off off"     # DLSS Ultra Performance mode, 1440p, Low settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1440p-low-rt-off-transformer"]="dlss-ultra-performance 2560x1440 low off off"     # DLSS Ultra Performance mode, 1440p, Low settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-low-rt-off-cnn"]="dlss-ultra-performance 2560x1440 low off off"             # DLSS Ultra Performance mode, 1440p, Low settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-medium-rt-off"]="dlss-ultra-performance 2560x1440 medium off off"           # DLSS Ultra Performance mode, 1440p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1440p-medium-rt-off-transformer"]="dlss-ultra-performance 2560x1440 medium off off" # DLSS Ultra Performance mode, 1440p, Medium settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-medium-rt-off-cnn"]="dlss-ultra-performance 2560x1440 medium off off"         # DLSS Ultra Performance mode, 1440p, Medium settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-high-rt-off"]="dlss-ultra-performance 2560x1440 high off off"                 # DLSS Ultra Performance mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1440p-high-rt-off-transformer"]="dlss-ultra-performance 2560x1440 high off off"     # DLSS Ultra Performance mode, 1440p, High settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-high-rt-off-cnn"]="dlss-ultra-performance 2560x1440 high off off"             # DLSS Ultra Performance mode, 1440p, High settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-ultra-rt-off"]="dlss-ultra-performance 2560x1440 ultra off off"                 # DLSS Ultra Performance mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-1440p-ultra-rt-off-transformer"]="dlss-ultra-performance 2560x1440 ultra off off"     # DLSS Ultra Performance mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-ultra-rt-off-cnn"]="dlss-ultra-performance 2560x1440 ultra off off"             # DLSS Ultra Performance mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-low-rt-on"]="dlss-ultra-performance 2560x1440 low on off"                   # DLSS Ultra Performance mode, 1440p, Low settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1440p-low-rt-on-transformer"]="dlss-ultra-performance 2560x1440 low on off"       # DLSS Ultra Performance mode, 1440p, Low settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-low-rt-on-cnn"]="dlss-ultra-performance 2560x1440 low on off"               # DLSS Ultra Performance mode, 1440p, Low settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-medium-rt-on"]="dlss-ultra-performance 2560x1440 medium on off"             # DLSS Ultra Performance mode, 1440p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1440p-medium-rt-on-transformer"]="dlss-ultra-performance 2560x1440 medium on off"   # DLSS Ultra Performance mode, 1440p, Medium settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-medium-rt-on-cnn"]="dlss-ultra-performance 2560x1440 medium on off"         # DLSS Ultra Performance mode, 1440p, Medium settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-high-rt-on"]="dlss-ultra-performance 2560x1440 high on off"                 # DLSS Ultra Performance mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1440p-high-rt-on-transformer"]="dlss-ultra-performance 2560x1440 high on off"     # DLSS Ultra Performance mode, 1440p, High settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-high-rt-on-cnn"]="dlss-ultra-performance 2560x1440 high on off"             # DLSS Ultra Performance mode, 1440p, High settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-1440p-ultra-rt-on"]="dlss-ultra-performance 2560x1440 ultra on off"               # DLSS Ultra Performance mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-1440p-ultra-rt-on-transformer"]="dlss-ultra-performance 2560x1440 ultra on off"   # DLSS Ultra Performance mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-1440p-ultra-rt-on-cnn"]="dlss-ultra-performance 2560x1440 ultra on off"           # DLSS Ultra Performance mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off (CNN)

# 4K DLSS tests
TESTS["dlss-performance-4k-low-rt-off"]="dlss-performance 3840x2160 low off off"                # DLSS Performance mode, 4K, Low settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-4k-high-rt-off"]="dlss-quality 3840x2160 high off off"                     # DLSS Quality mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-4k-high-rt-on"]="dlss-quality 3840x2160 high on off"                       # DLSS Quality mode, 4K, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-quality-4k-ultra-rt-off"]="dlss-quality 3840x2160 ultra off off"                   # DLSS Quality mode, 4K, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["dlss-quality-4k-ultra-rt-on"]="dlss-quality 3840x2160 ultra on off"                     # DLSS Quality mode, 4K, Ultra settings, Ray Tracing on, Frame Generation off
TESTS["dlss-balanced-4k-high-rt-off"]="dlss-balanced 3840x2160 high off off"                   # DLSS Balanced mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-performance-4k-high-rt-off"]="dlss-performance 3840x2160 high off off"           # DLSS Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-4k-low-rt-off"]="dlss-ultra-performance 3840x2160 low off off" # DLSS Ultra Performance mode, 4K, Low settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-4k-low-rt-off-transformer"]="dlss-ultra-performance 3840x2160 low off off" # DLSS Ultra Performance mode, 4K, Low settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-low-rt-off-cnn"]="dlss-ultra-performance 3840x2160 low off off" # DLSS Ultra Performance mode, 4K, Low settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-4k-medium-rt-off"]="dlss-ultra-performance 3840x2160 medium off off" # DLSS Ultra Performance mode, 4K, Medium settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-4k-medium-rt-off-transformer"]="dlss-ultra-performance 3840x2160 medium off off" # DLSS Ultra Performance mode, 4K, Medium settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-medium-rt-off-cnn"]="dlss-ultra-performance 3840x2160 medium off off" # DLSS Ultra Performance mode, 4K, Medium settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-4k-high-rt-off"]="dlss-ultra-performance 3840x2160 high off off" # DLSS Ultra Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-4k-high-rt-off-transformer"]="dlss-ultra-performance 3840x2160 high off off" # DLSS Ultra Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-high-rt-off-cnn"]="dlss-ultra-performance 3840x2160 high off off" # DLSS Ultra Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-4k-ultra-rt-off"]="dlss-ultra-performance 3840x2160 ultra off off"        # DLSS Ultra Performance mode, 4K, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["dlss-ultra-performance-4k-ultra-rt-off-transformer"]="dlss-ultra-performance 3840x2160 ultra off off"    # DLSS Ultra Performance mode, 4K, Ultra settings, Ray Tracing off, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-ultra-rt-off-cnn"]="dlss-ultra-performance 3840x2160 ultra off off" # DLSS Ultra Performance mode, 4K, Ultra settings, Ray Tracing off, Frame Generation off (CNN) 
TESTS["dlss-ultra-performance-4k-low-rt-on"]="dlss-ultra-performance 3840x2160 low on off"           # DLSS Ultra Performance mode, 4K, Low settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-4k-low-rt-on-transformer"]="dlss-ultra-performance 3840x2160 low on off"  # DLSS Ultra Performance mode, 4K, Low settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-low-rt-on-cnn"]="dlss-ultra-performance 3840x2160 low on off" # DLSS Ultra Performance mode, 4K, Low settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-4k-medium-rt-on"]="dlss-ultra-performance 3840x2160 medium on off" # DLSS Ultra Performance mode, 4K, Medium settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-4k-medium-rt-on-transformer"]="dlss-ultra-performance 3840x2160 medium on off" # DLSS Ultra Performance mode, 4K, Medium settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-medium-rt-on-cnn"]="dlss-ultra-performance 3840x2160 medium on off" # DLSS Ultra Performance mode, 4K, Medium settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-4k-high-rt-on"]="dlss-ultra-performance 3840x2160 high on off" # DLSS Ultra Performance mode, 4K, High settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-4k-high-rt-on-transformer"]="dlss-ultra-performance 3840x2160 high on off" # DLSS Ultra Performance mode, 4K, High settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-high-rt-on-cnn"]="dlss-ultra-performance 3840x2160 high on off" # DLSS Ultra Performance mode, 4K, High settings, Ray Tracing on, Frame Generation off (CNN)
TESTS["dlss-ultra-performance-4k-ultra-rt-on"]="dlss-ultra-performance 3840x2160 ultra on off" # DLSS Ultra Performance mode, 4K, Ultra settings, Ray Tracing on, Frame Generation off
TESTS["dlss-ultra-performance-4k-ultra-rt-on-transformer"]="dlss-ultra-performance 3840x2160 ultra on off" # DLSS Ultra Performance mode, 4K, Ultra settings, Ray Tracing on, Frame Generation off (Transformer)
TESTS["dlss-ultra-performance-4k-ultra-rt-on-cnn"]="dlss-ultra-performance 3840x2160 ultra on off" # DLSS Ultra Performance mode, 4K, Ultra settings, Ray Tracing on, Frame Generation off (CNN)

# DLSS 3 Frame Generation tests (only with compatible modes)
TESTS["dlss3-quality-1440p-high-rt-on-fg"]="dlss-quality 2560x1440 high on on"     # DLSS Quality mode, 1440p, High settings, Ray Tracing on, Frame Generation on
TESTS["dlss3-quality-1440p-ultra-rt-on-fg"]="dlss-quality 2560x1440 ultra on on"   # DLSS Quality mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation on
TESTS["dlss3-quality-4k-high-rt-on-fg"]="dlss-quality 3840x2160 high on on"        # DLSS Quality mode, 4K, High settings, Ray Tracing on, Frame Generation on
TESTS["dlss3-balanced-1440p-high-rt-on-fg"]="dlss-balanced 2560x1440 high on on"   # DLSS Balanced mode, 1440p, High settings, Ray Tracing on, Frame Generation on

# FSR 2.0 tests
TESTS["fsr2-quality-1080p-high-rt-off"]="fsr2-quality 1920x1080 high off off"       # FSR 2.0 Quality mode, 1080p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-quality-1080p-high-rt-on"]="fsr2-quality 1920x1080 high on off"       # FSR 2.0 Quality mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-quality-1440p-high-rt-off"]="fsr2-quality 2560x1440 high off off"     # FSR 2.0 Quality mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-quality-1440p-high-rt-on"]="fsr2-quality 2560x1440 high on off"       # FSR 2.0 Quality mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-quality-1440p-ultra-rt-off"]="fsr2-quality 2560x1440 ultra off off"   # FSR 2.0 Quality mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-quality-1440p-ultra-rt-on"]="fsr2-quality 2560x1440 ultra on off"     # FSR 2.0 Quality mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-quality-4k-high-rt-off"]="fsr2-quality 3840x2160 high off off"        # FSR 2.0 Quality mode, 4K, High settings, Ray Tracing off, Frame Generation off

TESTS["fsr2-balanced-1440p-high-rt-off"]="fsr2-balanced 2560x1440 high off off"     # FSR 2.0 Balanced mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1080p-low-rt-off"]="fsr2-performance 1920x1080 low off off" # FSR 2.0 Performance mode, 1080p, Low settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1080p-medium-rt-off"]="fsr2-performance 1920x1080 medium off off" # FSR 2.0 Performance mode, 1080p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1080p-high-rt-off"]="fsr2-performance 1920x1080 high off off"     # FSR 2.0 Performance mode, 1080p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1080p-ultra-rt-off"]="fsr2-performance 1920x1080 ultra off off"   # FSR 2.0 Performance mode, 1080p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1080p-low-rt-on"]="fsr2-performance 1920x1080 low on off"         # FSR 2.0 Performance mode, 1080p, Low settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-1080p-medium-rt-on"]="fsr2-performance 1920x1080 medium on off"   # FSR 2.0 Performance mode, 1080p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-1080p-high-rt-on"]="fsr2-performance 1920x1080 high on off"       # FSR 2.0 Performance mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-1080p-ultra-rt-on"]="fsr2-performance 1920x1080 ultra on off"     # FSR 2.0 Performance mode, 1080p, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["fsr2-performance-1440p-low-rt-off"]="fsr2-performance 2560x1440 low off off"       # FSR 2.0 Performance mode, 1440p, Low settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1440p-medium-rt-off"]="fsr2-performance 2560x1440 medium off off" # FSR 2.0 Performance mode, 1440p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1440p-high-rt-off"]="fsr2-performance 2560x1440 high off off"     # FSR 2.0 Performance mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1440p-ultra-rt-off"]="fsr2-performance 2560x1440 ultra off off"   # FSR 2.0 Performance mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-1440p-low-rt-on"]="fsr2-performance 2560x1440 low on off"         # FSR 2.0 Performance mode, 1440p, Low settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-1440p-medium-rt-on"]="fsr2-performance 2560x1440 medium on off"   # FSR 2.0 Performance mode, 1440p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-1440p-high-rt-on"]="fsr2-performance 2560x1440 high on off"       # FSR 2.0 Performance mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-1440p-ultra-rt-on"]="fsr2-performance 2560x1440 ultra on off"     # FSR 2.0 Performance mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["fsr2-performance-4k-low-rt-off"]="fsr2-performance 3840x2160 low off off"         # FSR 2.0 Performance mode, 4K, Low settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-4k-medium-rt-off"]="fsr2-performance 3840x2160 medium off off"   # FSR 2.0 Performance mode, 4K, Medium settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-4k-high-rt-off"]="fsr2-performance 3840x2160 high off off"       # FSR 2.0 Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-4k-ultra-rt-off"]="fsr2-performance 3840x2160 ultra off off"     # FSR 2.0 Performance mode, 4K, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["fsr2-performance-4k-low-rt-on"]="fsr2-performance 3840x2160 low on off"           # FSR 2.0 Performance mode, 4K, Low settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-4k-medium-rt-on"]="fsr2-performance 3840x2160 medium on off"     # FSR 2.0 Performance mode, 4K, Medium settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-4k-high-rt-on"]="fsr2-performance 3840x2160 high on off"         # FSR 2.0 Performance mode, 4K, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr2-performance-4k-ultra-rt-on"]="fsr2-performance 3840x2160 ultra on off"       # FSR 2.0 Performance mode, 4K, Ultra settings, Ray Tracing on, Frame Generation off

# FSR 2.1 tests
TESTS["fsr21-quality-1440p-high-rt-off"]="fsr21-quality 2560x1440 high off off"     # FSR 2.1 Quality mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr21-quality-1440p-high-rt-on"]="fsr21-quality 2560x1440 high on off"     # FSR 2.1 Quality mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr21-quality-4k-high-rt-off"]="fsr21-quality 3840x2160 high off off"       # FSR 2.1 Quality mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr21-balanced-1440p-high-rt-off"]="fsr21-balanced 2560x1440 high off off" # FSR 2.1 Balanced mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr21-performance-4k-high-rt-off"]="fsr21-performance 3840x2160 high off off" # FSR 2.1 Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off

# FSR 3.0 tests (with Frame Generation support)
TESTS["fsr3-quality-1440p-high-rt-off"]="fsr3-quality 2560x1440 high off off"     # FSR 3.0 Quality mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-quality-1440p-high-rt-on"]="fsr3-quality 2560x1440 high on off"       # FSR 3.0 Quality mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-quality-1440p-high-rt-off-fg"]="fsr3-quality 2560x1440 high off on"   # FSR 3.0 Quality mode, 1440p, High settings, Ray Tracing off, Frame Generation on
TESTS["fsr3-quality-1440p-high-rt-on-fg"]="fsr3-quality 2560x1440 high on on"     # FSR 3.0 Quality mode, 1440p, High settings, Ray Tracing on, Frame Generation on
TESTS["fsr3-quality-4k-high-rt-off"]="fsr3-quality 3840x2160 high off off"        # FSR 3.0 Quality mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-quality-4k-high-rt-off-fg"]="fsr3-quality 3840x2160 high off on"      # FSR 3.0 Quality mode, 4K, High settings, Ray Tracing off, Frame Generation on
TESTS["fsr3-balanced-1440p-high-rt-off-fg"]="fsr3-balanced 2560x1440 high off on" # FSR 3.0 Balanced mode, 1440p, High settings, Ray Tracing off, Frame Generation on

TESTS["fsr3-performance-1080p-low-rt-off"]="fsr3-performance 1920x1080 low off off" # FSR 3.0 Performance mode, 1080p, Low settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-1080p-medium-rt-off"]="fsr3-performance 1920x1080 medium off off" # FSR 3.0 Performance mode, 1080p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-1080p-high-rt-on"]="fsr3-performance 1920x1080 high on off"    # FSR 3.0 Performance mode, 1080p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-1080p-ultra-rt-on"]="fsr3-performance 1920x1080 ultra on off"  # FSR 3.0 Performance mode, 1080p, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["fsr3-performance-1440p-low-rt-off"]="fsr3-performance 2560x1440 low off off"       # FSR 3.0 Performance mode, 1440p, Low settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-1440p-medium-rt-off"]="fsr3-performance 2560x1440 medium off off" # FSR 3.0 Performance mode, 1440p, Medium settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-1440p-high-rt-off"]="fsr3-performance 2560x1440 high off off"     # FSR 3.0 Performance mode, 1440p, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-1440p-ultra-rt-off"]="fsr3-performance 2560x1440 ultra off off"   # FSR 3.0 Performance mode, 1440p, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-1440p-low-rt-on"]="fsr3-performance 2560x1440 low on off"         # FSR 3.0 Performance mode, 1440p, Low settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-1440p-medium-rt-on"]="fsr3-performance 2560x1440 medium on off"   # FSR 3.0 Performance mode, 1440p, Medium settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-1440p-high-rt-on"]="fsr3-performance 2560x1440 high on off"       # FSR 3.0 Performance mode, 1440p, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-1440p-ultra-rt-on"]="fsr3-performance 2560x1440 ultra on off"     # FSR 3.0 Performance mode, 1440p, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["fsr3-performance-4k-low-rt-off"]="fsr3-performance 3840x2160 low off off"          # FSR 3.0 Performance mode, 4K, Low settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-4k-medium-rt-off"]="fsr3-performance 3840x2160 medium off off"    # FSR 3.0 Performance mode, 4K, Medium settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-4k-high-rt-off"]="fsr3-performance 3840x2160 high off off"        # FSR 3.0 Performance mode, 4K, High settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-4k-ultra-rt-off"]="fsr3-performance 3840x2160 ultra off off"      # FSR 3.0 Performance mode, 4K, Ultra settings, Ray Tracing off, Frame Generation off
TESTS["fsr3-performance-4k-low-rt-on"]="fsr3-performance 3840x2160 low on off"            # FSR 3.0 Performance mode, 4K, Low settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-4k-medium-rt-on"]="fsr3-performance 3840x2160 medium on off"      # FSR 3.0 Performance mode, 4K, Medium settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-4k-high-rt-on"]="fsr3-performance 3840x2160 high on off"          # FSR 3.0 Performance mode, 4K, High settings, Ray Tracing on, Frame Generation off
TESTS["fsr3-performance-4k-ultra-rt-on"]="fsr3-performance 3840x2160 ultra on off"        # FSR 3.0 Performance mode, 4K, Ultra settings, Ray Tracing on, Frame Generation off

TESTS["fsr3-performance-4k-high-rt-off-fg"]="fsr3-performance 3840x2160 high off on"      # FSR 3.0 Performance mode, 4K, High settings, Ray Tracing off, Frame Generation on
