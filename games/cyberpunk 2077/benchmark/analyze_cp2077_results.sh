#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
PROFILES_DIR="${SCRIPT_DIR}/profiles"
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
TEMPLATE_FILE="${RESULTS_DIR}/cp2077_benchmark_report_template.md"
LATEST_REPORT_FILE="${RESULTS_DIR}/cp2077_benchmark_report.md"
TIMESTAMPED_REPORT_FILE="${RESULTS_DIR}/cp2077_benchmark_report_$(date +%Y%m%d_%H%M%S).md"

if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
	echo "Error: Tests config file not found: $TESTS_CONFIG_FILE" >&2
	exit 1
fi

mkdir -p "$RESULTS_DIR"

declare -A TESTS
# shellcheck source=/dev/null
source "$TESTS_CONFIG_FILE"

augment_tests_with_fg_variants() {
	for base_test_name in "${!TESTS[@]}"; do
		if [[ "$base_test_name" == *-fg* ]]; then
			continue
		fi

		for fg_suffix in "fg-dlss" "fg-frs31" "fg"; do
			local fg_test_name="${base_test_name}-${fg_suffix}"
			local fg_profile_file="${PROFILES_DIR}/UserSettings.${fg_test_name}.json"

			if [[ -f "$fg_profile_file" && -z "${TESTS[$fg_test_name]+isset}" ]]; then
				read -r mode resolution quality ray_tracing frame_generation <<<"${TESTS[$base_test_name]}"
				case "$fg_suffix" in
					fg-dlss)
						TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing fg-dlss"
						;;
					fg-frs31)
						TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing fg-frs31"
						;;
					*)
						TESTS["$fg_test_name"]="$mode $resolution $quality $ray_tracing on"
						;;
				esac
			fi
		done
	done
}

extract_fps_triplet() {
	local json_file="$1"
	python3 - "$json_file" <<'PY'
import json
import sys

path = sys.argv[1]
try:
	with open(path, "r", encoding="utf-8") as handle:
		payload = json.load(handle)
	data = payload.get("Data", {})
	mn = float(data.get("minFps"))
	avg = float(data.get("averageFps"))
	mx = float(data.get("maxFps"))
	print(f"{mn:.2f}|{avg:.2f}|{mx:.2f}")
except Exception:
	print("||")
PY
}

write_report_header() {
	local output_file="$1"
	local title="$2"
	local mode_label="$3"

	{
		echo "# ${title}"
		echo
		echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
		echo "- Source directory: ${RESULTS_DIR}"
		echo "- Mode: ${mode_label}"
		echo
		echo "| Test Name | Mode | Resolution | Quality | Ray Tracing | Frame Generation | Min FPS | Avg FPS | Max FPS |"
		echo "|---|---|---|---|---|---|---:|---:|---:|"
	} > "$output_file"
}

append_report_rows() {
	local output_file="$1"
	local fill_values="$2"
	local tests_written=0

	while IFS= read -r test_name; do
		read -r mode resolution quality ray_tracing frame_generation <<<"${TESTS[$test_name]}"

		if [[ "$fill_values" == "yes" ]]; then
			local min_value="${LATEST_MIN_FPS[$test_name]:-N/A}"
			local avg_value="${LATEST_AVG_FPS[$test_name]:-N/A}"
			local max_value="${LATEST_MAX_FPS[$test_name]:-N/A}"
			echo "| ${test_name} | ${mode} | ${resolution} | ${quality} | ${ray_tracing} | ${frame_generation} | ${min_value} | ${avg_value} | ${max_value} |" >> "$output_file"
		else
			echo "| ${test_name} | ${mode} | ${resolution} | ${quality} | ${ray_tracing} | ${frame_generation} |  |  |  |" >> "$output_file"
		fi

		tests_written=$((tests_written + 1))
	done < <(printf '%s\n' "${!TESTS[@]}" | sort)

	echo "$tests_written"
}

augment_tests_with_fg_variants

declare -A LATEST_RESULT_FILE
declare -A LATEST_TIMESTAMP
declare -A LATEST_MIN_FPS
declare -A LATEST_AVG_FPS
declare -A LATEST_MAX_FPS

shopt -s nullglob
result_files=("${RESULTS_DIR}"/*_result_*.json)
shopt -u nullglob

for result_file in "${result_files[@]}"; do
	file_name="$(basename "$result_file")"
	if [[ "$file_name" =~ ^[0-9]+_result_(.+)_([0-9]{8}_[0-9]{6})\.json$ ]]; then
		test_name="${BASH_REMATCH[1]}"
		result_timestamp="${BASH_REMATCH[2]}"

		if [[ -z "${LATEST_TIMESTAMP[$test_name]+isset}" || "$result_timestamp" > "${LATEST_TIMESTAMP[$test_name]}" ]]; then
			LATEST_TIMESTAMP["$test_name"]="$result_timestamp"
			LATEST_RESULT_FILE["$test_name"]="$result_file"
		fi
	fi
done

for test_name in "${!LATEST_RESULT_FILE[@]}"; do
	fps_triplet="$(extract_fps_triplet "${LATEST_RESULT_FILE[$test_name]}")"
	IFS='|' read -r min_fps avg_fps max_fps <<<"$fps_triplet"

	if [[ -n "$min_fps" && -n "$avg_fps" && -n "$max_fps" ]]; then
		LATEST_MIN_FPS["$test_name"]="$min_fps"
		LATEST_AVG_FPS["$test_name"]="$avg_fps"
		LATEST_MAX_FPS["$test_name"]="$max_fps"
	fi
done

write_report_header "$TEMPLATE_FILE" "Cyberpunk 2077 Benchmark Report Template" "Template (blank FPS cells)"
total_tests="$(append_report_rows "$TEMPLATE_FILE" "no")"

write_report_header "$LATEST_REPORT_FILE" "Cyberpunk 2077 Benchmark Report" "Latest result per test from JSON files"
append_report_rows "$LATEST_REPORT_FILE" "yes" >/dev/null
cp "$LATEST_REPORT_FILE" "$TIMESTAMPED_REPORT_FILE"

filled_tests=0
for test_name in "${!TESTS[@]}"; do
	if [[ -n "${LATEST_MIN_FPS[$test_name]+isset}" ]]; then
		filled_tests=$((filled_tests + 1))
	fi
done

echo "Generated template: $TEMPLATE_FILE"
echo "Generated report:   $LATEST_REPORT_FILE"
echo "Snapshot report:    $TIMESTAMPED_REPORT_FILE"
echo "Total test rows:    $total_tests"
echo "Rows with FPS data: $filled_tests"