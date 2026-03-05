#!/usr/bin/env bash
set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
RUNNER_SCRIPT="${SCRIPT_DIR}/run_deusex-md_benchmark.sh"
ANALYZER_SCRIPT="${SCRIPT_DIR}/analyze_deus-ex_results.sh"
AUTOMATION_SCRIPT="${SCRIPT_DIR}/automation_run.sh"
CONFIG_DIR="${SCRIPT_DIR}/config"

SMOKE_ENABLED=0
ANALYZE_ENABLED=0
PROFILE_VALIDATION_ENABLED=1
SMOKE_TEST_NAME="proton-1080p-low"
SMOKE_TIMEOUT_MINUTES="6"

TOTAL_CHECKS=0
FAILED_CHECKS=0

log_info() {
    printf '[INFO] %s\n' "$*"
}

log_ok() {
    printf '[ OK ] %s\n' "$*"
}

log_fail() {
    printf '[FAIL] %s\n' "$*"
}

show_help() {
    cat <<'EOF'
Deus Ex MD Benchmark Sanity Checks

Usage:
  ./run_sanity_checks.sh [OPTIONS]

Options:
  --smoke                      Run one real benchmark test (slow, launches the game)
  --smoke-test NAME            Benchmark test name for --smoke (default: proton-1080p-low)
  --smoke-timeout-minutes N    Per-test timeout used for --smoke (default: 6)
  --analyze                    Run result analyzer after sanity checks
  --skip-profiles              Skip profile validation check (--validate-profiles)
  --help, -h                   Show this help

Examples:
  ./run_sanity_checks.sh
  ./run_sanity_checks.sh --smoke
  ./run_sanity_checks.sh --smoke --smoke-test proton-1440p-low --smoke-timeout-minutes 8
  ./run_sanity_checks.sh --analyze
EOF
}

run_check() {
    local name="$1"
    shift

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    log_info "$name"

    if "$@"; then
        log_ok "$name"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        log_fail "$name"
    fi
}

run_check_shell() {
    local name="$1"
    local command_string="$2"

    TOTAL_CHECKS=$((TOTAL_CHECKS + 1))
    log_info "$name"

    if bash -lc "$command_string"; then
        log_ok "$name"
    else
        FAILED_CHECKS=$((FAILED_CHECKS + 1))
        log_fail "$name"
    fi
}

parse_args() {
    while [[ $# -gt 0 ]]; do
        case "$1" in
            --smoke)
                SMOKE_ENABLED=1
                shift
                ;;
            --smoke-test)
                if [[ -z "${2:-}" ]]; then
                    log_fail "--smoke-test requires a test name"
                    exit 2
                fi
                SMOKE_TEST_NAME="$2"
                shift 2
                ;;
            --smoke-timeout-minutes)
                if [[ -z "${2:-}" || ! "$2" =~ ^[0-9]+$ || "$2" -le 0 ]]; then
                    log_fail "--smoke-timeout-minutes requires a positive integer"
                    exit 2
                fi
                SMOKE_TIMEOUT_MINUTES="$2"
                shift 2
                ;;
            --analyze)
                ANALYZE_ENABLED=1
                shift
                ;;
            --skip-profiles)
                PROFILE_VALIDATION_ENABLED=0
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_fail "Unknown option: $1"
                show_help
                exit 2
                ;;
        esac
    done
}

main() {
    parse_args "$@"

    log_info "Starting sanity checks in: ${SCRIPT_DIR}"

    run_check "Benchmark runner exists" test -f "$RUNNER_SCRIPT"
    run_check "Analyzer exists" test -f "$ANALYZER_SCRIPT"
    run_check "Automation runner exists" test -f "$AUTOMATION_SCRIPT"
    run_check "Config directory exists" test -d "$CONFIG_DIR"

    run_check "Runner bash syntax" bash -n "$RUNNER_SCRIPT"
    run_check "Analyzer bash syntax" bash -n "$ANALYZER_SCRIPT"
    run_check "Automation bash syntax" bash -n "$AUTOMATION_SCRIPT"

    run_check_shell "Runner can list tests" "\"$RUNNER_SCRIPT\" --list >/dev/null"
    run_check_shell "Runner can list groups" "\"$RUNNER_SCRIPT\" --groups >/dev/null"
    run_check_shell "Runner exposes proton-1080p-low" "\"$RUNNER_SCRIPT\" --list | grep -q '^  proton-1080p-low$'"
    run_check_shell "Analyzer help works" "\"$ANALYZER_SCRIPT\" --help >/dev/null"

    if [[ "$PROFILE_VALIDATION_ENABLED" -eq 1 ]]; then
        run_check_shell "Runner profile validation" "\"$RUNNER_SCRIPT\" --validate-profiles >/dev/null"
    else
        log_info "Skipping profile validation (--skip-profiles)"
    fi

    if command -v shellcheck >/dev/null 2>&1; then
        run_check "ShellCheck runner" shellcheck "$RUNNER_SCRIPT"
        run_check "ShellCheck analyzer" shellcheck "$ANALYZER_SCRIPT"
        run_check "ShellCheck automation" shellcheck "$AUTOMATION_SCRIPT"
    else
        log_info "shellcheck not installed, skipping lint checks"
    fi

    if [[ "$SMOKE_ENABLED" -eq 1 ]]; then
        run_check_shell \
            "Smoke benchmark (${SMOKE_TEST_NAME})" \
            "\"$RUNNER_SCRIPT\" --proton --timeout-minutes \"$SMOKE_TIMEOUT_MINUTES\" \"$SMOKE_TEST_NAME\""
    else
        log_info "Skipping smoke benchmark (use --smoke to enable)"
    fi

    if [[ "$ANALYZE_ENABLED" -eq 1 ]]; then
        run_check_shell "Run analyzer" "\"$ANALYZER_SCRIPT\" >/dev/null"
    else
        log_info "Skipping analyzer run (use --analyze to enable)"
    fi

    printf '\n'
    log_info "Checks run: ${TOTAL_CHECKS}"
    log_info "Checks failed: ${FAILED_CHECKS}"

    if [[ "$FAILED_CHECKS" -gt 0 ]]; then
        log_fail "Sanity check failed"
        exit 1
    fi

    log_ok "Sanity check passed"
    exit 0
}

main "$@"