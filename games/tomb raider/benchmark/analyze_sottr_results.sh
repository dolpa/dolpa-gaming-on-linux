#!/usr/bin/env bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

SYSTEM_NAME_DEFAULT="$(hostname -s 2>/dev/null || echo "default")"
SYSTEM_NAME_DEFAULT="${SYSTEM_NAME_DEFAULT,,}"
SYSTEM_NAME_DEFAULT="$(printf '%s' "$SYSTEM_NAME_DEFAULT" | sed -E 's/pavel//g; s/dolpa//g; s/[-_.]+/-/g; s/^-+|-+$//g')"
if [[ -z "$SYSTEM_NAME_DEFAULT" ]]; then
	SYSTEM_NAME_DEFAULT="default"
fi
SYSTEM_NAME="${SOTTR_SYSTEM_NAME:-${SYSTEM_NAME:-$SYSTEM_NAME_DEFAULT}}"
SYSTEM_NAME="${SYSTEM_NAME// /_}"

SYSTEM_CONFIG_DIR="${PROJECT_ROOT_DIR}/system"
SYSTEM_CONFIG_LOCAL_FILE="${SYSTEM_CONFIG_DIR}/system.${SYSTEM_NAME}.conf.sh"
SYSTEM_CONFIG_OVERRIDE_FILE="${SOTTR_BENCHMARK_CONFIG:-}"
SOTTR_PROTON_VERSION_DEFAULT="GE-Proton9-27"
GAME_ID=750920
STEAM_PATH="${HOME}/.local/share/Steam"
CUSTOM_LIBRARY_PATH="/mnt/Data/Games/Steam"

RESULTS_DIR="${SCRIPT_DIR}/results"
PROFILES_DIR="${SCRIPT_DIR}/profiles"
TESTS_CONFIG_FILE="${SCRIPT_DIR}/config/tests.conf.sh"
GROUPS_CONFIG_FILE="${SCRIPT_DIR}/config/groups.conf.sh"
TEMPLATE_FILE="${RESULTS_DIR}/sottr_benchmark_report_template.md"
LATEST_REPORT_FILE="${RESULTS_DIR}/sottr_benchmark_report.md"
TIMESTAMPED_REPORT_FILE="${RESULTS_DIR}/sottr_benchmark_report_$(date +%Y%m%d_%H%M%S).md"
BASH_UTILS_LOADER="${SCRIPT_DIR}/../../../dolpa-bash-utils/bash-utils.sh"
GAME_README_FILE="${SCRIPT_DIR}/../README.md"
TEST_RESULTS_START_MARKER="<!-- TEST_RESULTS_START -->"
TEST_RESULTS_END_MARKER="<!-- TEST_RESULTS_END -->"
TEST_RESULTS_PLACEHOLDER="- _No reports added yet._"

if [[ -f "$SYSTEM_CONFIG_LOCAL_FILE" ]]; then
	# shellcheck source=/dev/null
	source "$SYSTEM_CONFIG_LOCAL_FILE"
fi

if [[ -n "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
	if [[ ! -f "$SYSTEM_CONFIG_OVERRIDE_FILE" ]]; then
		echo "Error: SOTTR_BENCHMARK_CONFIG file not found: $SYSTEM_CONFIG_OVERRIDE_FILE" >&2
		exit 1
	fi
	# shellcheck source=/dev/null
	source "$SYSTEM_CONFIG_OVERRIDE_FILE"
fi

# Proton selection precedence:
# 1) SOTTR_PROTON_VERSION (game-specific override)
# 2) SOTTR_PROTON_VERSION_DEFAULT (game default)
# 3) PROTON_VERSION (shared system default)
PROTON_VERSION="${SOTTR_PROTON_VERSION:-${SOTTR_PROTON_VERSION_DEFAULT:-${PROTON_VERSION:-}}}"

REPORT_SYSTEM_OS="${REPORT_SYSTEM_OS:-Ubuntu 24.04.4 LTS}"
REPORT_SYSTEM_KERNEL="${REPORT_SYSTEM_KERNEL:-6.17.0-14-generic}"
REPORT_SYSTEM_CPU="${REPORT_SYSTEM_CPU:-Intel Core Ultra 7 265KF}"
REPORT_SYSTEM_GPU="${REPORT_SYSTEM_GPU:-NVIDIA GeForce RTX 5060}"
REPORT_SYSTEM_GPU_DRIVER="${REPORT_SYSTEM_GPU_DRIVER:-NVIDIA 590.48.01}"
REPORT_SYSTEM_RAM="${REPORT_SYSTEM_RAM:-48 GB}"
REPORT_SYSTEM_PROTON="${REPORT_SYSTEM_PROTON:-${PROTON_VERSION:-}}"

if [[ -z "${BENCHMARK_RESULTS_SOURCE_DIR:-}" ]]; then
	local_native_results_dir="${HOME}/.local/share/feral-interactive/Shadow of the Tomb Raider/SaveData"
	local_proton_results_dir="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Shadow of the Tomb Raider/"
	local_proton_results_dir_alt="${CUSTOM_LIBRARY_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/My Documents/Shadow of the Tomb Raider/"
	local_steam_results_dir="${STEAM_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/Documents/Shadow of the Tomb Raider/"
	local_steam_results_dir_alt="${STEAM_PATH}/steamapps/compatdata/${GAME_ID}/pfx/drive_c/users/steamuser/My Documents/Shadow of the Tomb Raider/"

	if [[ -d "$local_native_results_dir" ]]; then
		BENCHMARK_RESULTS_SOURCE_DIR="$local_native_results_dir"
	elif [[ -d "$local_proton_results_dir" ]]; then
		BENCHMARK_RESULTS_SOURCE_DIR="$local_proton_results_dir"
	elif [[ -d "$local_proton_results_dir_alt" ]]; then
		BENCHMARK_RESULTS_SOURCE_DIR="$local_proton_results_dir_alt"
	elif [[ -d "$local_steam_results_dir" ]]; then
		BENCHMARK_RESULTS_SOURCE_DIR="$local_steam_results_dir"
	elif [[ -d "$local_steam_results_dir_alt" ]]; then
		BENCHMARK_RESULTS_SOURCE_DIR="$local_steam_results_dir_alt"
	else
		BENCHMARK_RESULTS_SOURCE_DIR="$local_native_results_dir"
	fi
fi

if [[ ! -f "$BASH_UTILS_LOADER" ]]; then
	echo "Error: dolpa-bash-utils loader not found: $BASH_UTILS_LOADER" >&2
	exit 1
fi

# shellcheck source=/dev/null
source "$BASH_UTILS_LOADER"

if [[ ! -f "$TESTS_CONFIG_FILE" ]]; then
	log_error "Tests config file not found: $TESTS_CONFIG_FILE"
	exit 1
fi

if [[ ! -f "$GROUPS_CONFIG_FILE" ]]; then
	log_error "Test groups config file not found: $GROUPS_CONFIG_FILE"
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
	echo "Tomb Raider Benchmark Results Analyzer"
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
					log_error "--group requires a group name"
					exit 1
				fi
				REQUESTED_GROUPS+=("$2")
				shift 2
				;;
			-*)
				log_error "Unknown option $1"
				log_error "Use --help for usage information."
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
			log_error "Unknown test group '$group_name'. Use --list-groups to inspect available groups."
			exit 1
		fi

		read -ra group_tests <<<"${TEST_GROUPS[$group_name]}"
		for test_name in "${group_tests[@]}"; do
			if [[ -z "${TESTS[$test_name]+isset}" ]]; then
				log_error "Group '$group_name' references unknown test '$test_name'."
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
			log_error "Unknown test '$test_name'. Use --list-tests to inspect available tests."
			exit 1
		fi
		if [[ -z "${seen[$test_name]+isset}" ]]; then
			SELECTED_TESTS+=("$test_name")
			seen["$test_name"]=1
		fi
	done

	if [[ ${#SELECTED_TESTS[@]} -eq 0 ]]; then
		log_error "No tests selected for reporting."
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
			local fg_profile_file_rise="${PROFILES_DIR}/${fg_test_name}.profile.conf.sh"

			if [[ -f "$fg_profile_file_rise" && -z "${TESTS[$fg_test_name]+isset}" ]]; then
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

join_unique_values() {
	if [[ $# -eq 0 ]]; then
		echo "N/A"
		return
	fi

	printf '%s\n' "$@" \
		| awk 'NF' \
		| sort -u \
		| awk 'BEGIN { first = 1 } { if (!first) printf ", "; printf "%s", $0; first = 0 } END { if (NR == 0) printf "N/A"; printf "\n" }'
}

collect_selected_gpu_metadata() {
	local -A selected_tests_lookup=()
	local -A gpu_models=()
	local -A gpu_vrams=()
	local -A gpu_drivers=()
	local key key_test gpu_model gpu_vram gpu_driver

	for test_name in "${SELECTED_TESTS[@]}"; do
		selected_tests_lookup["$test_name"]=1
	done

	for key in "${!LATEST_RESULT_FILE_BY_KEY[@]}"; do
		if [[ -z "${selected_tests_lookup[${key%%|*}]+isset}" ]]; then
			continue
		fi

		if [[ -z "${LATEST_MIN_FPS_BY_KEY[$key]+isset}" || -z "${LATEST_AVG_FPS_BY_KEY[$key]+isset}" || -z "${LATEST_MAX_FPS_BY_KEY[$key]+isset}" ]]; then
			continue
		fi

		IFS='|' read -r key_test gpu_model gpu_vram gpu_driver <<<"$key"
		gpu_models["$gpu_model"]=1
		gpu_vrams["$gpu_vram"]=1
		gpu_drivers["$gpu_driver"]=1
	done

	REPORT_GPU_MODELS="$(join_unique_values "${!gpu_models[@]}")"
	REPORT_GPU_VRAMS="$(join_unique_values "${!gpu_vrams[@]}")"
	REPORT_GPU_DRIVERS="$(join_unique_values "${!gpu_drivers[@]}")"
}

write_report_header() {
	local output_file="$1"
	local title="$2"
	local mode_label="$3"
	local gpu_models="$4"
	local gpu_vrams="$5"
	local gpu_drivers="$6"

	{
		echo "# ${title}"
		echo
		echo "- Generated: $(date '+%Y-%m-%d %H:%M:%S %Z')"
		echo "- JSON archive directory: ${RESULTS_DIR}"
		echo "- Benchmark source directory: ${BENCHMARK_RESULTS_SOURCE_DIR}"
		echo "- Mode: ${mode_label}"
		echo "- OS: ${REPORT_SYSTEM_OS}"
		echo "- KERNEL: ${REPORT_SYSTEM_KERNEL}"
		echo "- CPU: ${REPORT_SYSTEM_CPU}"
		echo "- RAM: ${REPORT_SYSTEM_RAM}"
		echo "- GPU: ${REPORT_SYSTEM_GPU}"
		echo "- GPU DRIVER: ${REPORT_SYSTEM_GPU_DRIVER}"
		echo "- GPU VRAM: ${gpu_vrams}"
		echo "- Proton: ${REPORT_SYSTEM_PROTON}"
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

ensure_test_results_section_exists() {
	if [[ ! -f "$GAME_README_FILE" ]]; then
		log_warning "Game README file not found, skipping report link registration: $GAME_README_FILE"
		return 1
	fi

	if grep -Fq "$TEST_RESULTS_START_MARKER" "$GAME_README_FILE" && grep -Fq "$TEST_RESULTS_END_MARKER" "$GAME_README_FILE"; then
		return 0
	fi

	{
		echo
		echo "## Test Results"
		echo
		echo "Latest report files:"
		echo
		echo "- [benchmark/results/sottr_benchmark_report_template.md](benchmark/results/sottr_benchmark_report_template.md)"
		echo "- [benchmark/results/sottr_benchmark_report.md](benchmark/results/sottr_benchmark_report.md)"
		echo
		echo "Historical snapshot reports (auto-updated by \\`benchmark/analyze_sottr_results.sh\\`):"
		echo
		echo "$TEST_RESULTS_START_MARKER"
		echo "$TEST_RESULTS_PLACEHOLDER"
		echo "$TEST_RESULTS_END_MARKER"
	} >> "$GAME_README_FILE"

	log_info "Added missing Test Results section to: $GAME_README_FILE"
	return 0
}

register_report_link_in_readme() {
	local report_file="$1"

	ensure_test_results_section_exists || return 0

	local report_basename
	report_basename="$(basename "$report_file")"
	local relative_report_path="benchmark/results/${report_basename}"
	local markdown_link="- [${report_basename}](${relative_report_path})"

	if grep -Fq "$markdown_link" "$GAME_README_FILE"; then
		log_info "Report link already registered in README: $report_basename"
		return 0
	fi

	local temp_file
	temp_file="$(mktemp)"

	awk \
		-v start_marker="$TEST_RESULTS_START_MARKER" \
		-v end_marker="$TEST_RESULTS_END_MARKER" \
		-v placeholder="$TEST_RESULTS_PLACEHOLDER" \
		-v new_link="$markdown_link" \
		'
		$0 == start_marker {
			print
			print new_link
			in_results_block = 1
			next
		}
		$0 == end_marker {
			in_results_block = 0
		}
		in_results_block && $0 == placeholder {
			next
		}
		{
			print
		}
		' "$GAME_README_FILE" > "$temp_file"

	mv "$temp_file" "$GAME_README_FILE"
	log_success "Registered report link in README: $report_basename"
}

register_all_snapshot_report_links_in_readme() {
	ensure_test_results_section_exists || return 0

	local -a snapshot_files
	local -a sorted_snapshot_files
	local -A seen_snapshot_basenames=()
	shopt -s nullglob
	snapshot_files=("${RESULTS_DIR}"/sottr_benchmark_report_[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]_[0-9][0-9][0-9][0-9][0-9][0-9].md)
	shopt -u nullglob

	local links_file
	links_file="$(mktemp)"

	if [[ ${#snapshot_files[@]} -eq 0 ]]; then
		echo "$TEST_RESULTS_PLACEHOLDER" > "$links_file"
	else
		mapfile -t sorted_snapshot_files < <(printf '%s\n' "${snapshot_files[@]}" | sort -r)

		local snapshot_file snapshot_basename relative_report_path
		for snapshot_file in "${sorted_snapshot_files[@]}"; do
			snapshot_basename="$(basename "$snapshot_file")"
			if [[ -n "${seen_snapshot_basenames[$snapshot_basename]+isset}" ]]; then
				continue
			fi

			relative_report_path="benchmark/results/${snapshot_basename}"
			echo "- [${snapshot_basename}](${relative_report_path})" >> "$links_file"
			seen_snapshot_basenames["$snapshot_basename"]=1
		done

		if [[ ! -s "$links_file" ]]; then
			echo "$TEST_RESULTS_PLACEHOLDER" > "$links_file"
		fi
	fi

	local temp_file
	temp_file="$(mktemp)"

	awk \
		-v start_marker="$TEST_RESULTS_START_MARKER" \
		-v end_marker="$TEST_RESULTS_END_MARKER" \
		-v links_file="$links_file" \
		'
		$0 == start_marker {
			print
			while ((getline link_line < links_file) > 0) {
				print link_line
			}
			close(links_file)
			in_results_block = 1
			next
		}
		$0 == end_marker {
			in_results_block = 0
			print
			next
		}
		in_results_block {
			next
		}
		{
			print
		}
		' "$GAME_README_FILE" > "$temp_file"

	rm -f "$links_file"
	mv "$temp_file" "$GAME_README_FILE"
	log_success "Synchronized snapshot report links in README (newest first, no duplicates)."
}

build_quick_resolution_variant_groups() {
	add_test_and_rt_pair_if_available() {
		local target_array_name="$1"
		local mapped_test_name="$2"

		if [[ -z "${TESTS[$mapped_test_name]+isset}" ]]; then
			return
		fi

		eval "$target_array_name+=(\"$mapped_test_name\")"

		local counterpart_test_name=""
		if [[ "$mapped_test_name" == *-rt-off* ]]; then
			counterpart_test_name="${mapped_test_name/-rt-off/-rt-on}"
		elif [[ "$mapped_test_name" == *-rt-on* ]]; then
			counterpart_test_name="${mapped_test_name/-rt-on/-rt-off}"
		fi

		if [[ -n "$counterpart_test_name" && -n "${TESTS[$counterpart_test_name]+isset}" ]]; then
			eval "$target_array_name+=(\"$counterpart_test_name\")"
		fi
	}

	local source_group_name
	for source_group_name in "${!TEST_GROUPS[@]}"; do
		[[ "$source_group_name" == 4k-quick-* ]] || continue

		local group_suffix="${source_group_name#4k-quick-}"
		local target_group_1080p="1080p-quick-${group_suffix}"
		local target_group_1440p="1440p-quick-${group_suffix}"

		read -ra source_tests <<<"${TEST_GROUPS[$source_group_name]}"

		local -a mapped_1080p_tests=()
		local -a mapped_1440p_tests=()
		local -A seen_1080p_tests=()
		local -A seen_1440p_tests=()
		local source_test mapped_test

		for source_test in "${source_tests[@]}"; do
			mapped_test="${source_test//-4k-/-1080p-}"
			add_test_and_rt_pair_if_available "mapped_1080p_tests" "$mapped_test"

			mapped_test="${source_test//-4k-/-1440p-}"
			add_test_and_rt_pair_if_available "mapped_1440p_tests" "$mapped_test"
		done

		local -a deduped_1080p_tests=()
		for mapped_test in "${mapped_1080p_tests[@]}"; do
			if [[ -z "${seen_1080p_tests[$mapped_test]+isset}" ]]; then
				deduped_1080p_tests+=("$mapped_test")
				seen_1080p_tests["$mapped_test"]=1
			fi
		done

		local -a deduped_1440p_tests=()
		for mapped_test in "${mapped_1440p_tests[@]}"; do
			if [[ -z "${seen_1440p_tests[$mapped_test]+isset}" ]]; then
				deduped_1440p_tests+=("$mapped_test")
				seen_1440p_tests["$mapped_test"]=1
			fi
		done

		if [[ ${#deduped_1080p_tests[@]} -gt 0 ]]; then
			TEST_GROUPS["$target_group_1080p"]="${deduped_1080p_tests[*]}"
		fi

		if [[ ${#deduped_1440p_tests[@]} -gt 0 ]]; then
			TEST_GROUPS["$target_group_1440p"]="${deduped_1440p_tests[*]}"
		fi
	done
}

augment_tests_with_fg_variants
build_quick_resolution_variant_groups
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

REPORT_GPU_MODELS="N/A"
REPORT_GPU_VRAMS="N/A"
REPORT_GPU_DRIVERS="N/A"
collect_selected_gpu_metadata

write_report_header "$TEMPLATE_FILE" "Shadow of the Tomb Raider Benchmark Report Template" "Template (blank FPS cells)" "$REPORT_GPU_MODELS" "$REPORT_GPU_VRAMS" "$REPORT_GPU_DRIVERS"
total_tests="$(append_template_rows "$TEMPLATE_FILE")"

write_report_header "$LATEST_REPORT_FILE" "Shadow of the Tomb Raider Benchmark Report" "Latest result per test from JSON files" "$REPORT_GPU_MODELS" "$REPORT_GPU_VRAMS" "$REPORT_GPU_DRIVERS"
filled_rows="$(append_latest_rows "$LATEST_REPORT_FILE")"
cp "$LATEST_REPORT_FILE" "$TIMESTAMPED_REPORT_FILE"
register_all_snapshot_report_links_in_readme

filled_tests=0
for test_name in "${SELECTED_TESTS[@]}"; do
	if grep -q "^| ${test_name} |" "$LATEST_REPORT_FILE"; then
		filled_tests=$((filled_tests + 1))
	fi
done

log_success "Generated template: $TEMPLATE_FILE"
log_success "Generated report:   $LATEST_REPORT_FILE"
log_success "Snapshot report:    $TIMESTAMPED_REPORT_FILE"
log_info "Total test rows:    $total_tests"
log_info "Rows with FPS data: $filled_tests"
log_info "Rows in report:     $filled_rows"
log_info "Selected tests:     ${#SELECTED_TESTS[@]}"