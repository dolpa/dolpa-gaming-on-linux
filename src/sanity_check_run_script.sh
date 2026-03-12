#!/usr/bin/env bash

set -u

SELF_NAME="$(basename "$0")"
SELF_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
REPO_ROOT="$(cd "${SELF_DIR}/.." && pwd)"

PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
SKIP_COUNT=0
PRESERVE_TMP=0

COLOR_ENABLED=0
if [[ -t 1 ]] && [[ -z "${NO_COLOR:-}" ]]; then
    COLOR_ENABLED=1
fi

color_text() {
    local color_code="$1"
    shift

    if [[ "$COLOR_ENABLED" -eq 1 ]]; then
        printf '\033[%sm%s\033[0m' "$color_code" "$*"
    else
        printf '%s' "$*"
    fi
}

log_info() {
    printf '%s %s\n' "$(color_text '36' '[INFO]')" "$*"
}

log_pass() {
    PASS_COUNT=$((PASS_COUNT + 1))
    printf '%s %s\n' "$(color_text '32' '[PASS]')" "$*"
}

log_warn() {
    WARN_COUNT=$((WARN_COUNT + 1))
    PRESERVE_TMP=1
    printf '%s %s\n' "$(color_text '33' '[WARN]')" "$*"
}

log_fail() {
    FAIL_COUNT=$((FAIL_COUNT + 1))
    PRESERVE_TMP=1
    printf '%s %s\n' "$(color_text '31' '[FAIL]')" "$*"
}

log_skip() {
    SKIP_COUNT=$((SKIP_COUNT + 1))
    printf '%s %s\n' "$(color_text '34' '[SKIP]')" "$*"
}

usage() {
    cat <<EOF
Quick sanity checker for benchmark run scripts.

Usage:
  ${SELF_NAME} <path-to-run-script>

Example:
  ${SELF_NAME} games/ac valhalla/benchmark/run_ac-valhalla_benchmark.sh
  ${SELF_NAME} "games\\ac valhalla\\benchmark\\run_ac-valhalla_benchmark.sh"

What it checks:
  - target file exists and is readable
  - Bash syntax parses cleanly
  - common safe CLI entry points respond: --help, --list, --groups, --validate-profiles
  - command output is non-empty and returns expected status where possible

Notes:
  - this script never runs the actual benchmark workload
  - warnings from --validate-profiles are treated as non-fatal when the script reaches validation logic
EOF
}

normalize_path_separators() {
    printf '%s' "${1//\\//}"
}

is_absolute_path() {
    case "$1" in
        /*|[A-Za-z]:/*)
            return 0
            ;;
        *)
            return 1
            ;;
    esac
}

canonicalize_existing_path() {
    local input_path="$1"
    local dir_name
    local base_name

    dir_name="$(dirname "$input_path")"
    base_name="$(basename "$input_path")"

    (
        cd "$dir_name" >/dev/null 2>&1 || exit 1
        printf '%s/%s\n' "$PWD" "$base_name"
    )
}

resolve_target_script() {
    local raw_input="$1"
    local normalized_input
    local candidate

    normalized_input="$(normalize_path_separators "$raw_input")"

    if is_absolute_path "$normalized_input"; then
        if [[ -e "$normalized_input" ]]; then
            canonicalize_existing_path "$normalized_input"
            return 0
        fi
        return 1
    fi

    for candidate in "$normalized_input" "$REPO_ROOT/$normalized_input"; do
        if [[ -e "$candidate" ]]; then
            canonicalize_existing_path "$candidate"
            return 0
        fi
    done

    return 1
}

path_for_display() {
    local target_path="$1"
    case "$target_path" in
        "$REPO_ROOT"/*)
            printf '%s\n' "${target_path#"$REPO_ROOT"/}"
            ;;
        *)
            printf '%s\n' "$target_path"
            ;;
    esac
}

show_output_snippet() {
    local output_file="$1"
    local max_lines="${2:-12}"

    if [[ ! -s "$output_file" ]]; then
        printf '      | <no output>\n'
        return 0
    fi

    sed -n "1,${max_lines}p" "$output_file" | sed 's/^/      | /'
}

run_with_timeout() {
    local timeout_seconds="$1"
    shift
    local output_file="$1"
    shift

    : > "$output_file"

    (
        export CI=1
        export TERM=dumb
        export NO_COLOR=1
        export CLICOLOR=0
        cd "$COMMAND_WORKDIR" >/dev/null 2>&1 || exit 1
        "$@"
    ) >"$output_file" 2>&1 &
    local cmd_pid=$!
    local elapsed=0

    while kill -0 "$cmd_pid" >/dev/null 2>&1; do
        if (( elapsed >= timeout_seconds )); then
            kill "$cmd_pid" >/dev/null 2>&1 || true
            sleep 1
            kill -9 "$cmd_pid" >/dev/null 2>&1 || true
            wait "$cmd_pid" >/dev/null 2>&1 || true
            return 124
        fi
        sleep 1
        elapsed=$((elapsed + 1))
    done

    wait "$cmd_pid"
}

help_mentions_flag() {
    local help_file="$1"
    local flag="$2"

    grep -Fq -- "$flag" "$help_file"
}

run_safe_probe() {
    local probe_name="$1"
    local timeout_seconds="$2"
    local mode="$3"
    shift 3

    local output_file="$TMP_DIR/${probe_name}.log"
    local rc

    log_info "Running ${probe_name} probe: $*"
    run_with_timeout "$timeout_seconds" "$output_file" "$@"
    rc=$?

    if [[ "$rc" -eq 124 ]]; then
        log_fail "${probe_name} timed out after ${timeout_seconds}s."
        show_output_snippet "$output_file"
        return 1
    fi

    if [[ "$mode" == "strict" ]]; then
        if [[ "$rc" -ne 0 ]]; then
            log_fail "${probe_name} exited with code ${rc}."
            show_output_snippet "$output_file"
            return 1
        fi

        if [[ ! -s "$output_file" ]]; then
            log_warn "${probe_name} succeeded but produced no output."
            return 0
        fi

        log_pass "${probe_name} responded successfully."
        return 0
    fi

    if [[ "$mode" == "validate-profiles" ]]; then
        if [[ "$rc" -eq 0 ]]; then
            log_pass "${probe_name} completed successfully."
            return 0
        fi

        if grep -Eiq 'missing|not found|validation failed|profile validation failed|profiles directory not found' "$output_file"; then
            log_warn "${probe_name} reported missing benchmark assets, but validation logic is reachable."
            show_output_snippet "$output_file"
            return 0
        fi

        log_fail "${probe_name} exited with code ${rc}."
        show_output_snippet "$output_file"
        return 1
    fi

    log_fail "Unknown probe mode: ${mode}"
    return 1
}

cleanup() {
    if [[ -n "${TMP_DIR:-}" && -d "${TMP_DIR:-}" ]]; then
        if [[ "$PRESERVE_TMP" -eq 1 || -n "${KEEP_SANITY_TMP:-}" ]]; then
            log_info "Preserved probe logs in: ${TMP_DIR}"
        else
            rm -rf "$TMP_DIR"
        fi
    fi
}

main() {
    local target_input="${1:-}"
    local target_script
    local target_display
    local target_dir
    local help_output
    local shebang
    local syntax_output

    if [[ "$#" -ne 1 ]] || [[ "$target_input" == "--help" ]] || [[ "$target_input" == "-h" ]]; then
        usage
        exit 1
    fi

    if ! target_script="$(resolve_target_script "$target_input")"; then
        printf '%s Could not resolve target script: %s\n' "$(color_text '31' '[FAIL]')" "$target_input"
        exit 1
    fi

    target_display="$(path_for_display "$target_script")"
    target_dir="$(dirname "$target_script")"

    if [[ "$target_script" == "$REPO_ROOT"/* ]]; then
        COMMAND_WORKDIR="$REPO_ROOT"
    else
        COMMAND_WORKDIR="$target_dir"
    fi

    TMP_DIR="$(mktemp -d "${TMPDIR:-/tmp}/script-sanity.XXXXXX")"
    trap cleanup EXIT

    log_info "Target script: ${target_display}"
    log_info "Working directory for probes: $(path_for_display "$COMMAND_WORKDIR")"

    if [[ ! -f "$target_script" ]]; then
        log_fail "Target is not a regular file."
        exit 1
    fi

    if [[ ! -r "$target_script" ]]; then
        log_fail "Target is not readable."
        exit 1
    fi

    log_pass "Target file exists and is readable."

    if [[ -x "$target_script" ]]; then
        log_pass "Target file is executable."
    else
        log_warn "Target file is not marked executable; probes will still use bash explicitly."
    fi

    shebang="$(head -n 1 "$target_script" 2>/dev/null || true)"
    if [[ "$shebang" == '#!/usr/bin/env bash' || "$shebang" == '#!/bin/bash' ]]; then
        log_pass "Shebang looks Bash-compatible."
    else
        log_warn "Unexpected shebang: ${shebang:-<missing>}"
    fi

    if [[ -d "$target_dir/config" ]]; then
        log_pass "Sibling config directory detected."
    else
        log_warn "Sibling config directory was not found."
    fi

    if [[ -f "$REPO_ROOT/dolpa-bash-utils/bash-utils.sh" ]]; then
        log_pass "Shared bash utils loader is present in repository."
    else
        log_warn "Shared bash utils loader not found at repository root."
    fi

    syntax_output="$TMP_DIR/bash-syntax.log"
    if bash -n "$target_script" >"$syntax_output" 2>&1; then
        log_pass "Bash syntax check passed."
    else
        log_fail "Bash syntax check failed."
        show_output_snippet "$syntax_output"
    fi

    help_output="$TMP_DIR/help.log"
    run_with_timeout "20" "$help_output" bash "$target_script" --help
    case "$?" in
        0)
            if [[ -s "$help_output" ]]; then
                if grep -Eiq 'usage:|options:|--help|benchmark' "$help_output"; then
                    log_pass "Help output looks valid."
                else
                    log_warn "Help command succeeded but output did not match common help markers."
                    show_output_snippet "$help_output"
                fi
            else
                log_warn "Help command succeeded but produced no output."
            fi
            ;;
        124)
            log_fail "Help command timed out."
            show_output_snippet "$help_output"
            ;;
        *)
            log_fail "Help command failed."
            show_output_snippet "$help_output"
            ;;
    esac

    if [[ -s "$help_output" ]]; then
        if help_mentions_flag "$help_output" '--list'; then
            run_safe_probe "list" "20" "strict" bash "$target_script" --list
        else
            log_skip "Skipping --list probe; help output does not advertise it."
        fi

        if help_mentions_flag "$help_output" '--groups'; then
            run_safe_probe "groups" "20" "strict" bash "$target_script" --groups
        else
            log_skip "Skipping --groups probe; help output does not advertise it."
        fi

        if help_mentions_flag "$help_output" '--validate-profiles'; then
            run_safe_probe "validate-profiles" "30" "validate-profiles" bash "$target_script" --validate-profiles
        else
            log_skip "Skipping --validate-profiles probe; help output does not advertise it."
        fi
    else
        log_skip "Skipping secondary probes because help output was unavailable."
    fi

    printf '\n%s pass=%d warn=%d fail=%d skip=%d\n' \
        "$(color_text '1' 'Summary:')" \
        "$PASS_COUNT" "$WARN_COUNT" "$FAIL_COUNT" "$SKIP_COUNT"

    if [[ "$FAIL_COUNT" -gt 0 ]]; then
        exit 1
    fi

    exit 0
}

main "$@"
