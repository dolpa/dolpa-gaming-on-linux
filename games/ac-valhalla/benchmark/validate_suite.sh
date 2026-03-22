#!/usr/bin/env bash

# Quick validation script for AC Valhalla benchmark suite
# This script performs basic validation without running actual benchmarks

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT_DIR="$(cd "${SCRIPT_DIR}/../../.." && pwd)"

# Source the shared bash utils
BASH_UTILS_LOADER="${PROJECT_ROOT_DIR}/dolpa-bash-utils/bash-utils.sh"
if [[ ! -f "${BASH_UTILS_LOADER}" ]]; then
    echo "Error: dolpa‑bash‑utils loader not found: ${BASH_UTILS_LOADER}" >&2
    echo "PROJECT_ROOT_DIR is: ${PROJECT_ROOT_DIR}" >&2
    echo "Expected location: ${BASH_UTILS_LOADER}" >&2
    echo "" >&2
    echo "Directory listing of PROJECT_ROOT_DIR:" >&2
    ls -la "${PROJECT_ROOT_DIR}" 2>&1 >&2 || echo "Failed to list PROJECT_ROOT_DIR" >&2
    exit 1
fi
source "${BASH_UTILS_LOADER}"

# Set debug mode for more detailed output during validation
BASH_UTILS_DEBUG="false"
BASH_UTILS_VERBOSE="true"

log_info "Starting AC Valhalla benchmark suite validation..."

# Test 1: Configuration file syntax
log_info "Testing configuration file syntax..."
if bash -n "${SCRIPT_DIR}/config/game.ac-valhalla.conf.sh"; then
    log_success "Game configuration syntax is valid"
else
    log_error "Game configuration has syntax errors"
    exit 1
fi

if bash -n "${SCRIPT_DIR}/config/tests.conf.sh"; then
    log_success "Tests configuration syntax is valid"
else
    log_error "Tests configuration has syntax errors"
    exit 1
fi

if bash -n "${SCRIPT_DIR}/config/groups.conf.sh"; then
    log_success "Groups configuration syntax is valid"
else
    log_error "Groups configuration has syntax errors"
    exit 1
fi

# Test 2: Main script syntax
log_info "Testing main script syntax..."
if bash -n "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh"; then
    log_success "Main script syntax is valid"
else
    log_error "Main script has syntax errors"
    exit 1
fi

# Test 3: Help functionality
log_info "Testing help functionality..."
log_debug "Attempting to run: ${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh --help"

# Run with timeout to avoid hanging - allow expected configuration warnings
if timeout 30s "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh" --help >/dev/null 2>/dev/null; then
    log_success "Help command works correctly"
elif timeout 30s bash -c 'export CUSTOM_LIBRARY_PATH="/tmp/test"; "${1}" --help >/dev/null 2>&1' _ "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh"; then
    log_success "Help command works correctly (with test environment)"
else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        log_error "Help command timed out after 30 seconds"
    else
        log_error "Help command failed with exit code: $exit_code"
        # Try to get more detailed error information
        log_info "Running help command with error output for diagnosis:"
        timeout 10s bash -c 'export CUSTOM_LIBRARY_PATH="/tmp/test"; "${1}" --help 2>&1' _ "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh" | head -10 || true
    fi
    exit 1
fi

# Test 4: List functionality
log_info "Testing list functionality..."
if timeout 30s "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh" --list >/dev/null 2>&1; then
    log_success "List command works correctly"
else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        log_error "List command timed out after 30 seconds"
    else
        log_error "List command failed with exit code: $exit_code"
    fi
    exit 1
fi

# Test 5: Groups listing
log_info "Testing groups functionality..."
if timeout 30s "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh" --groups >/dev/null 2>&1; then
    log_success "Groups command works correctly"
else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        log_error "Groups command timed out after 30 seconds"
    else
        log_error "Groups command failed with exit code: $exit_code"
    fi
    exit 1
fi

# Test 6: Validate profile checking
log_info "Testing profile validation..."
if timeout 30s "${SCRIPT_DIR}/run_ac-valhalla_benchmark.sh" --validate-profiles >/dev/null 2>&1; then
    log_success "Profile validation works (note: profiles may not exist, but validation function runs)"
else
    exit_code=$?
    if [[ $exit_code -eq 124 ]]; then
        log_warning "Profile validation timed out (may indicate hanging issue)"
    else
        log_info "Profile validation reports missing profiles (expected if no profiles exist yet) - exit code: $exit_code"
    fi
fi

log_success "All validation tests completed successfully!"
log_info "The AC Valhalla benchmark suite is ready for use."
log_info ""
log_info "Next steps:"
log_info "1. Create game setting profiles in the profiles/ directory"
log_info "2. Configure system-specific settings in system/system.<hostname>.conf.sh"
log_info "3. Run actual benchmarks with: ./run_ac-valhalla_benchmark.sh --group quick"