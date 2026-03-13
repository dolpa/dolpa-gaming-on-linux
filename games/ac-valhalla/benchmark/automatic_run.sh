#!/usr/bin/env bash
set -euo pipefail


# This script is intended for running Assassin's Creed Valhalla benchmark in an unattended way, with auto-clicking the "Run All" button in the benchmark UI.

export GAME_ID="2208920"
export PROTON_BIN="${HOME}/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton"
export GAME_EXE="/mnt/Data/Games/Steam/steamapps/common/Assassin's Creed Valhalla/ACValhalla.exe"
export GAME_DIR="/mnt/Data/Games/Steam/steamapps/common/Assassin's Creed Valhalla"
export STEAM_COMPAT_DATA_PATH="/mnt/Data/Games/Steam/steamapps/compatdata/${GAME_ID}"
export STEAM_COMPAT_CLIENT_INSTALL_PATH="${HOME}/.local/share/Steam"
export PROTON_VERB="waitforexitandrun"
export STEAM_RUNTIME=1
export BENCHMARK="taiga"
export BENCHMARK_PRESET="${BENCHMARK_PRESET:-Low}"
export BENCHMARK_RUNS="${BENCHMARK_RUNS:-1}"
export BENCHMARK_TRACK="${BENCHMARK_TRACK:-m3\\12_valley_benchmark}"
export AUTO_CLICK_TIMEOUT_SEC="${AUTO_CLICK_TIMEOUT_SEC:-60}"
export RUN_ALL_BUTTON_SCREEN_X="${RUN_ALL_BUTTON_SCREEN_X:-3220}"
export RUN_ALL_BUTTON_SCREEN_Y="${RUN_ALL_BUTTON_SCREEN_Y:-1945}"
export RUN_ALL_CLICK_RETRIES="${RUN_ALL_CLICK_RETRIES:-3}"
export CONFIRM_YES_SCREEN_X="${CONFIRM_YES_SCREEN_X:-3107}"
export CONFIRM_YES_SCREEN_Y="${CONFIRM_YES_SCREEN_Y:-1801}"
export CONFIRM_YES_CLICK_RETRIES="${CONFIRM_YES_CLICK_RETRIES:-4}"
export PRESET_ITEM_SCREEN_X="${PRESET_ITEM_SCREEN_X:-3000}"
export PRESET_ITEM_SCREEN_Y="${PRESET_ITEM_SCREEN_Y:-1654}"
export PRESET_CLICK_RETRIES="${PRESET_CLICK_RETRIES:-2}"

if [[ ! -x "$PROTON_BIN" ]]; then
	echo "Proton not found or not executable: $PROTON_BIN" >&2
	exit 1
fi

if [[ ! -f "$GAME_EXE" ]]; then
	echo "Game executable not found: $GAME_EXE" >&2
	exit 1
fi

if ! command -v xdotool >/dev/null 2>&1; then
	echo "xdotool is required for unattended benchmark run (auto-press Run button)." >&2
	echo "Install it: sudo apt update && sudo apt install -y xdotool" >&2
	exit 1
fi

cd "$GAME_DIR"

# cat > benchmark.ini <<EOF
# [Settings]
# Preset=${BENCHMARK_PRESET}
# Run=${BENCHMARK_RUNS}
# Quit=1
# EOF

auto_select_preset_and_run_all() {
	local win_id=""
	local attempts=$((AUTO_CLICK_TIMEOUT_SEC * 2))
	for _ in $(seq 1 "$attempts"); do
		win_id="$(xdotool search --name "ASSASSIN'S CREED VALHALLA Benchmark" 2>/dev/null | head -n1 || true)"
		if [[ -n "$win_id" ]]; then
			local width height
			width="$(xdotool getwindowgeometry --shell "$win_id" 2>/dev/null | awk -F= '/^WIDTH=/{print $2}')"
			height="$(xdotool getwindowgeometry --shell "$win_id" 2>/dev/null | awk -F= '/^HEIGHT=/{print $2}')"

			if [[ -z "$width" || -z "$height" ]]; then
				width=1600
				height=900
			fi

			local run_all_x_default=$((width - 120))
			local run_all_y_default=$((height - 34))
			local run_all_x="${RUN_ALL_BUTTON_X:-$run_all_x_default}"
			local run_all_y="${RUN_ALL_BUTTON_Y:-$run_all_y_default}"
			local run_all_screen_x="${RUN_ALL_BUTTON_SCREEN_X:-}"
			local run_all_screen_y="${RUN_ALL_BUTTON_SCREEN_Y:-}"
			local confirm_yes_x="${CONFIRM_YES_SCREEN_X:-}"
			local confirm_yes_y="${CONFIRM_YES_SCREEN_Y:-}"
			local preset_x_default=$((width / 5))
			local preset_y_default=$((height / 2))
			local preset_x="${PRESET_ITEM_X:-$preset_x_default}"
			local preset_y="${PRESET_ITEM_Y:-$preset_y_default}"
			local preset_screen_x="${PRESET_ITEM_SCREEN_X:-}"
			local preset_screen_y="${PRESET_ITEM_SCREEN_Y:-}"

			if (( run_all_x < 1 )); then run_all_x=1; fi
			if (( run_all_y < 1 )); then run_all_y=1; fi
			if (( preset_x < 1 )); then preset_x=1; fi
			if (( preset_y < 1 )); then preset_y=1; fi

			xdotool windowactivate "$win_id" >/dev/null 2>&1 || true
			xdotool windowraise "$win_id" >/dev/null 2>&1 || true
			sleep 0.6

			# if [[ -n "$preset_screen_x" && -n "$preset_screen_y" ]]; then
			# 	for _ in $(seq 1 "$PRESET_CLICK_RETRIES"); do
			# 		xdotool mousemove --sync "$preset_screen_x" "$preset_screen_y" >/dev/null 2>&1 || true
			# 		xdotool click 1 >/dev/null 2>&1 || true
			# 		sleep 0.25
			# 	done
			# else
			# 	for _ in $(seq 1 "$PRESET_CLICK_RETRIES"); do
			# 		xdotool mousemove --window "$win_id" --sync "$preset_x" "$preset_y" >/dev/null 2>&1 || true
			# 		xdotool click --window "$win_id" 1 >/dev/null 2>&1 || true
			# 		sleep 0.25
			# 	done
			# fi

			sleep 0.35
			if [[ -n "$run_all_screen_x" && -n "$run_all_screen_y" ]]; then
				for _ in $(seq 1 "$RUN_ALL_CLICK_RETRIES"); do
					xdotool mousemove --sync "$run_all_screen_x" "$run_all_screen_y" >/dev/null 2>&1 || true
					xdotool click 1 >/dev/null 2>&1 || true
					sleep 0.25
				done
			else
				for _ in $(seq 1 "$RUN_ALL_CLICK_RETRIES"); do
					xdotool mousemove --window "$win_id" --sync "$run_all_x" "$run_all_y" >/dev/null 2>&1 || true
					xdotool click --window "$win_id" 1 >/dev/null 2>&1 || true
					sleep 0.25
				done
			fi

			sleep 0.35
			if [[ -n "$confirm_yes_x" && -n "$confirm_yes_y" ]]; then
				for _ in $(seq 1 "$CONFIRM_YES_CLICK_RETRIES"); do
					xdotool mousemove --sync "$confirm_yes_x" "$confirm_yes_y" >/dev/null 2>&1 || true
					xdotool click 1 >/dev/null 2>&1 || true
					sleep 0.3
				done
			fi
			return 0
		fi
		sleep 0.5
	done
	return 1
}

AUTO_PRESS_PID=""

cleanup() {
	if [[ -n "$AUTO_PRESS_PID" ]]; then
		kill "$AUTO_PRESS_PID" >/dev/null 2>&1 || true
	fi
}

trap cleanup EXIT

# auto_select_preset_and_run_all &
# AUTO_PRESS_PID=$!

timeout --foreground --signal=TERM --kill-after=20s 600s \
	env PROTON_LOG=1 \
	SteamAppId="$GAME_ID" \
	SteamGameId="$GAME_ID" \
	VKD3D_FEATURE_LEVEL=12_2 \
	PROTON_HIDE_NVIDIA_GPU=0 \
	PROTON_ENABLE_NVAPI=1 \
	VKD3D_CONFIG=dxr12 \
	DXVK_ASYNC=1 \
	"$HOME/.local/share/Steam/compatibilitytools.d/GE-Proton10-32/proton" \
	run "/mnt/Data/Games/Steam/steamapps/common/Assassin's Creed Valhalla/ACValhalla.exe" \
	-uplay_steam_mode \
	-benchmark \
	-skipStartScreen