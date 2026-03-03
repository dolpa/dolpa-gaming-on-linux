# Tomb Raider benchmark Proton test definitions
# This file is sourced by run_sottr_benchmark.sh in Proton mode.
# Required by caller: declare -A TESTS
# Format: TESTS["test-name"]="mode resolution quality ray_tracing frame_generation directx12"

# Scope requested for Proton runs:
# - DirectX 12: on/off
# - Upscaling mode: DLSS Ultra Performance
# - Graphics presets: low/medium/high/ultra

add_proton_ultra_perf_tests() {
	local res_label="$1"
	local resolution="$2"
	local quality

	for quality in low medium high ultra; do
		TESTS["proton-dx12-on-dlss-ultra-performance-${res_label}-${quality}"]="dlss-ultra-performance ${resolution} ${quality} off off on"
		TESTS["proton-dx12-off-dlss-ultra-performance-${res_label}-${quality}"]="dlss-ultra-performance ${resolution} ${quality} off off off"
	done
}

add_proton_ultra_perf_tests "1080p" "1920x1080"
add_proton_ultra_perf_tests "1440p" "2560x1440"
add_proton_ultra_perf_tests "4k" "3840x2160"
