#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RESULTS_DIR="${SCRIPT_DIR}/results"
PROFILES_DIR="${SCRIPT_DIR}/profiles"
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.conf.sh"
TEMPLATE_FILE="${RESULTS_DIR}/cp2077_benchmark_report_template.md"
LATEST_REPORT_FILE="${RESULTS_DIR}/cp2077_benchmark_report.md"
TIMESTAMPED_REPORT_FILE="${RESULTS_DIR}/cp2077_benchmark_report_$(date +%Y%m%d_%H%M%S).md"

if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
	echo "Error: Tests config file not found: $TESTS_CONFIG_FILE" >&2
	exit 1
fi

if [[ ! -f "$GROUPS_CONFIG_FILE" ]]; then
	echo "Error: Test groups config file not found: $GROUPS_CONFIG_FILE" >&2
	exit 1
fi

mkdir -p "$RESULTS_DIR"

declare -A TESTS
declare -A TEST_GROUPS

declare -a REQUESTED_TESTS=()
declare -a REQUESTED_GROUPS=()
declare -a SELECTED_TESTS=()

# shellcheck source=/dev/null
source "$TESTS_CONFIG_FILE"
# shellcheck source=/dev/null
source "$GROUPS_CONFIG_FILE"

show_help() {
	echo "Cyberpunk 2077 Benchmark Results Analyzer"
	echo "Usage: $0 [OPTIONS] [TEST_NAME ...]"
	echo
	echo "OPTIONS:"
	echo "  --help, -h            Show this help message"
	echo "  --group GROUP_NAME    Include all tests from a group (repeatable)"
	echo "  --list-tests          List all available test names"
	echo "  --list-groups         List available test groups"
	echo
	echo "FILTERING:"
	echo "  - If no tests/groups are specified, all tests are considered."
	echo "  - Positional arguments are treated as test names."
	echo "  - You can combine --group and explicit test names."
	echo
	echo "Examples:"
	echo "  $0"
	echo "  $0 --group quick-4k"
	echo "  $0 --group quick-4k dlss-quality-4k-high-rt-on"
}

list_tests() {
	echo "Available tests:"
	printf '%s\n' "${!TESTS[@]}" | sort
}

list_groups() {
	echo "Available groups:"
	for group_name in "${!TEST_GROUPS[@]}"; do
		echo "  $group_name: ${TEST_GROUPS[$group_name]}"
	done | sort
}

parse_arguments() {
	while [[ $# -gt 0 ]]; do
		case "$1" in
			--help|-h)
				show_help
				exit 0
				;;
			--list-tests)
				list_tests
				exit 0
				;;
			--list-groups)
				list_groups
				exit 0
				;;
			--group)
				if [[ -z "${2:-}" ]]; then
					echo "Error: --group requires a group name" >&2
					exit 1
				fi
				REQUESTED_GROUPS+=("$2")
				shift 2
				;;
			-*)
				echo "Error: Unknown option $1" >&2
				echo "Use --help for usage information." >&2
				exit 1
				;;
			*)
				REQUESTED_TESTS+=("$1")
				shift
				;;
		esac
	done
}

select_tests_for_report() {
	local -A seen=()

	if [[ ${#REQUESTED_GROUPS[@]} -eq 0 && ${#REQUESTED_TESTS[@]} -eq 0 ]]; then
		mapfile -t SELECTED_TESTS < <(printf '%s\n' "${!TESTS[@]}" | sort)
		return
	fi

	for group_name in "${REQUESTED_GROUPS[@]}"; do
		if [[ -z "${TEST_GROUPS[$group_name]+isset}" ]]; then
			echo "Error: Unknown test group '$group_name'. Use --list-groups to inspect available groups." >&2
			exit 1
		fi

		read -ra group_tests <<<"${TEST_GROUPS[$group_name]}"
		for test_name in "${group_tests[@]}"; do
			if [[ -z "${TESTS[$test_name]+isset}" ]]; then
				echo "Error: Group '$group_name' references unknown test '$test_name'." >&2
				exit 1
			fi
			if [[ -z "${seen[$test_name]+isset}" ]]; then
				SELECTED_TESTS+=("$test_name")
				seen["$test_name"]=1
			fi
		done
	done

	for test_name in "${REQUESTED_TESTS[@]}"; do
		if [[ -z "${TESTS[$test_name]+isset}" ]]; then
			echo "Error: Unknown test '$test_name'. Use --list-tests to inspect available tests." >&2
			exit 1
		fi
		if [[ -z "${seen[$test_name]+isset}" ]]; then
			SELECTED_TESTS+=("$test_name")
			seen["$test_name"]=1
		fi
	done

	if [[ ${#SELECTED_TESTS[@]} -eq 0 ]]; then
		echo "Error: No tests selected for reporting." >&2
		exit 1
	fi
}

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
		echo "| Test Name | Mode | Resolution | Quality | Ray Tracing | Frame Generation | GPU Model | GPU VRAM | Driver | Min FPS | Avg FPS | Max FPS |"
		echo "|---|---|---|---|---|---|---|---|---|---:|---:|---:|"
	} > "$output_file"
}

append_template_rows() {
	local output_file="$1"
	local tests_written=0

	for test_name in "${SELECTED_TESTS[@]}"; do
		read -r mode resolution quality ray_tracing frame_generation <<<"${TESTS[$test_name]}"
		echo "| ${test_name} | ${mode} | ${resolution} | ${quality} | ${ray_tracing} | ${frame_generation} |  |  |  |  |  |  |" >> "$output_file"
		tests_written=$((tests_written + 1))
	done

	echo "$tests_written"
}

append_latest_rows() {
	local output_file="$1"
	local rows_written=0
	local key test_name mode resolution quality ray_tracing frame_generation
	local key_test gpu_model gpu_vram gpu_driver

	mapfile -t sorted_keys < <(printf '%s\n' "${!LATEST_RESULT_FILE_BY_KEY[@]}" | sort)

	for test_name in "${SELECTED_TESTS[@]}"; do
		read -r mode resolution quality ray_tracing frame_generation <<<"${TESTS[$test_name]}"

		for key in "${sorted_keys[@]}"; do
			IFS='|' read -r key_test gpu_model gpu_vram gpu_driver <<<"$key"
			if [[ "$key_test" != "$test_name" ]]; then
				continue
			fi

			if [[ -z "${LATEST_MIN_FPS_BY_KEY[$key]+isset}" || -z "${LATEST_AVG_FPS_BY_KEY[$key]+isset}" || -z "${LATEST_MAX_FPS_BY_KEY[$key]+isset}" ]]; then
				continue
			fi

			echo "| ${test_name} | ${mode} | ${resolution} | ${quality} | ${ray_tracing} | ${frame_generation} | ${gpu_model} | ${gpu_vram} | ${gpu_driver} | ${LATEST_MIN_FPS_BY_KEY[$key]} | ${LATEST_AVG_FPS_BY_KEY[$key]} | ${LATEST_MAX_FPS_BY_KEY[$key]} |" >> "$output_file"
			rows_written=$((rows_written + 1))
		done
	done

	echo "$rows_written"
}

augment_tests_with_fg_variants
parse_arguments "$@"
select_tests_for_report

declare -A LATEST_RESULT_FILE_BY_KEY
declare -A LATEST_TIMESTAMP_BY_KEY
declare -A LATEST_MIN_FPS_BY_KEY
declare -A LATEST_AVG_FPS_BY_KEY
declare -A LATEST_MAX_FPS_BY_KEY

shopt -s nullglob
result_files=("${RESULTS_DIR}"/*_result_*.json)
shopt -u nullglob

for result_file in "${result_files[@]}"; do
	file_name="$(basename "$result_file")"
	if [[ "$file_name" =~ ^[0-9]+_result_(.+)_([^_]+)_([^_]+)_([^_]+)_([0-9]{8}_[0-9]{6})\.json$ ]]; then
		test_name="${BASH_REMATCH[1]}"
		gpu_model="${BASH_REMATCH[2]}"
		gpu_vram="${BASH_REMATCH[3]}"
		gpu_driver="${BASH_REMATCH[4]}"
		result_timestamp="${BASH_REMATCH[5]}"
		result_key="${test_name}|${gpu_model}|${gpu_vram}|${gpu_driver}"

		if [[ -z "${LATEST_TIMESTAMP_BY_KEY[$result_key]+isset}" || "$result_timestamp" > "${LATEST_TIMESTAMP_BY_KEY[$result_key]}" ]]; then
			LATEST_TIMESTAMP_BY_KEY["$result_key"]="$result_timestamp"
			LATEST_RESULT_FILE_BY_KEY["$result_key"]="$result_file"
		fi
	elif [[ "$file_name" =~ ^[0-9]+_result_(.+)_([0-9]{8}_[0-9]{6})\.json$ ]]; then
		test_name="${BASH_REMATCH[1]}"
		result_timestamp="${BASH_REMATCH[2]}"
		result_key="${test_name}|unknown-gpu|unknown-vram|unknown-driver"

		if [[ -z "${LATEST_TIMESTAMP_BY_KEY[$result_key]+isset}" || "$result_timestamp" > "${LATEST_TIMESTAMP_BY_KEY[$result_key]}" ]]; then
			LATEST_TIMESTAMP_BY_KEY["$result_key"]="$result_timestamp"
			LATEST_RESULT_FILE_BY_KEY["$result_key"]="$result_file"
		fi
	fi
done

for result_key in "${!LATEST_RESULT_FILE_BY_KEY[@]}"; do
	fps_triplet="$(extract_fps_triplet "${LATEST_RESULT_FILE_BY_KEY[$result_key]}")"
	IFS='|' read -r min_fps avg_fps max_fps <<<"$fps_triplet"

	if [[ -n "$min_fps" && -n "$avg_fps" && -n "$max_fps" ]]; then
		LATEST_MIN_FPS_BY_KEY["$result_key"]="$min_fps"
		LATEST_AVG_FPS_BY_KEY["$result_key"]="$avg_fps"
		LATEST_MAX_FPS_BY_KEY["$result_key"]="$max_fps"
	fi
done

write_report_header "$TEMPLATE_FILE" "Cyberpunk 2077 Benchmark Report Template" "Template (blank FPS cells)"
total_tests="$(append_template_rows "$TEMPLATE_FILE")"

write_report_header "$LATEST_REPORT_FILE" "Cyberpunk 2077 Benchmark Report" "Latest result per test from JSON files"
filled_rows="$(append_latest_rows "$LATEST_REPORT_FILE")"
cp "$LATEST_REPORT_FILE" "$TIMESTAMPED_REPORT_FILE"

filled_tests=0
for test_name in "${SELECTED_TESTS[@]}"; do
	if grep -q "^| ${test_name} |" "$LATEST_REPORT_FILE"; then
		filled_tests=$((filled_tests + 1))
	fi
done

echo "Generated template: $TEMPLATE_FILE"
echo "Generated report:   $LATEST_REPORT_FILE"
echo "Snapshot report:    $TIMESTAMPED_REPORT_FILE"
echo "Total test rows:    $total_tests"
echo "Rows with FPS data: $filled_tests"
echo "Rows in report:     $filled_rows"
echo "Selected tests:     ${#SELECTED_TESTS[@]}"