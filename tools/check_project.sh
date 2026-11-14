#!/usr/bin/env bash
# Runs every automatic check on the project. Run it before every commit.
#
# Usage (Git Bash, macOS or Linux), from anywhere:
#     tools/check_project.sh
# Set GODOT_EXECUTABLE if Godot is not at the default path below.
#
# The checks:
#   1. Import: Godot loads every script, scene and image. Any error fails.
#   2. Tests:  every tests/test_*.gd runs through tests/TestRunner.tscn.
#   3. Scenes: every scene in scenes/ runs for 60 frames without an error.

godot_executable="${GODOT_EXECUTABLE:-/c/dev/Godot/Godot_v4.7.2-stable_win64_console.exe}"
project_folder="$(cd "$(dirname "$0")/.." && pwd)"
failed_step_count=0

# Runs Godot with the given arguments and fails the step when Godot exits
# with an error code or prints an error line.
run_step() {
	local step_name="$1"
	shift
	local step_output
	step_output="$("$godot_executable" --headless --path "$project_folder" "$@" 2>&1)"
	local exit_code=$?
	if [ $exit_code -ne 0 ] || echo "$step_output" | grep -q "ERROR"; then
		echo "FAILED  $step_name"
		echo "$step_output" | grep -v "^$" | sed 's/^/        /'
		failed_step_count=$((failed_step_count + 1))
	else
		echo "passed  $step_name"
	fi
}

run_step "import" --import
run_step "tests" res://tests/TestRunner.tscn

while IFS= read -r scene_file_path; do
	scene_resource_path="res://${scene_file_path#"$project_folder"/}"
	run_step "scene $scene_resource_path" --quit-after 60 "$scene_resource_path"
done < <(find "$project_folder/scenes" -name "*.tscn" | sort)

if [ $failed_step_count -eq 0 ]; then
	echo "All checks passed."
else
	echo "$failed_step_count check(s) failed."
	exit 1
fi
