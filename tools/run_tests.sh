#!/usr/bin/env bash
# Runs the headless test suite from a clean state.
#
# Godot resolves `class_name` types from .godot/global_script_class_cache.cfg,
# which is not in version control. Importing first rebuilds it, so tests
# behave the same on a fresh clone as on a machine that has opened the editor.
set -euo pipefail
cd "$(dirname "$0")/.."
GODOT="${GODOT:-godot}"

"$GODOT" --headless --import --path . >/dev/null 2>&1 || true
# A script that fails to parse can leave Godot idling; never hang CI.
timeout 600 "$GODOT" --headless --path . res://tests/test_runner.tscn
