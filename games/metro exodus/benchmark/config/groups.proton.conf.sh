# Metro Exodus benchmark Proton test groups
# This file is sourced by run_metro_exodus_benchmark.sh in Proton mode.
# Required by caller: declare -A TEST_GROUPS

build_proton_ultra_perf_groups() {
	local -a resolutions=("1080p" "1440p" "4k")
	local -a qualities=("low" "medium" "high" "ultra")

	local all_on=""
	local all_off=""
	local all_proton=""
	local quick=""

	local res quality on_name off_name
	for res in "${resolutions[@]}"; do
		local by_res=""
		for quality in "${qualities[@]}"; do
			on_name="proton-dx12-on-dlss-ultra-performance-${res}-${quality}"
			off_name="proton-dx12-off-dlss-ultra-performance-${res}-${quality}"

			all_on+=" ${on_name}"
			all_off+=" ${off_name}"
			all_proton+=" ${on_name} ${off_name}"
			by_res+=" ${on_name} ${off_name}"

			TEST_GROUPS["proton-dx12-comparison-${quality}-${res}"]="${on_name} ${off_name}"
		done

		quick+=" proton-dx12-on-dlss-ultra-performance-${res}-high proton-dx12-off-dlss-ultra-performance-${res}-high"
		TEST_GROUPS["proton-${res}"]="${by_res# }"
	done

	TEST_GROUPS["proton-quick"]="${quick# }"
	TEST_GROUPS["proton-dx12-on"]="${all_on# }"
	TEST_GROUPS["proton-dx12-off"]="${all_off# }"
	TEST_GROUPS["all-proton"]="${all_proton# }"
}

build_proton_ultra_perf_groups
