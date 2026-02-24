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
		echo "| Test Name | Mode | Resolution | Quality | Ray Tracing | Frame Generation | Min FPS | Avg FPS | Max FPS |"
		echo "|---|---|---|---|---|---|---:|---:|---:|"
	} > "$output_file"
}

append_report_rows() {
	local output_file="$1"
	local fill_values="$2"
	local tests_written=0

	for test_name in "${SELECTED_TESTS[@]}"; do
		read -r mode resolution quality ray_tracing frame_generation <<<"${TESTS[$test_name]}"

		if [[ "$fill_values" == "yes" ]]; then
			if [[ -z "${LATEST_MIN_FPS[$test_name]+isset}" || -z "${LATEST_AVG_FPS[$test_name]+isset}" || -z "${LATEST_MAX_FPS[$test_name]+isset}" ]]; then
				continue
			fi

			local min_value="${LATEST_MIN_FPS[$test_name]}"
			local avg_value="${LATEST_AVG_FPS[$test_name]}"
			local max_value="${LATEST_MAX_FPS[$test_name]}"
			echo "| ${test_name} | ${mode} | ${resolution} | ${quality} | ${ray_tracing} | ${frame_generation} | ${min_value} | ${avg_value} | ${max_value} |" >> "$output_file"
		else
			echo "| ${test_name} | ${mode} | ${resolution} | ${quality} | ${ray_tracing} | ${frame_generation} |  |  |  |" >> "$output_file"
		fi

		tests_written=$((tests_written + 1))
	done

	echo "$tests_written"
}

augment_tests_with_fg_variants
parse_arguments "$@"
select_tests_for_report

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
filled_rows="$(append_report_rows "$LATEST_REPORT_FILE" "yes")"
cp "$LATEST_REPORT_FILE" "$TIMESTAMPED_REPORT_FILE"

filled_tests=0
for test_name in "${SELECTED_TESTS[@]}"; do
	if [[ -n "${LATEST_MIN_FPS[$test_name]+isset}" ]]; then
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