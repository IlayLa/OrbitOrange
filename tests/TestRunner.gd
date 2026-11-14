extends Node
## Runs every test file in res://tests and exits.
##
## How to run:   godot --headless res://tests/TestRunner.tscn
## Exit code 0 means every check passed; 1 means at least one failed.
##
## How to add tests: create res://tests/test_<something>.gd that extends
## RefCounted and has the function
##     func run_tests(report: TestReport) -> void
## It is found and run automatically. Owned by the integrator.

const TESTS_FOLDER_PATH := "res://tests"
const TEST_FILE_PREFIX := "test_"
const TEST_FILE_SUFFIX := ".gd"


func _ready() -> void:
	var report := TestReport.new()
	for test_file_name in _find_test_file_names():
		print("\n", test_file_name)
		var test_script: GDScript = load(TESTS_FOLDER_PATH + "/" + test_file_name)
		var test_object: Object = test_script.new()
		if test_object.has_method("run_tests"):
			test_object.call("run_tests", report)
		else:
			report.check(false, test_file_name + " has a run_tests function")

	print("\n%d checks passed, %d failed." % [report.passed_check_count, report.failed_check_count])
	for failure_description in report.failure_descriptions:
		print("  FAILED: ", failure_description)
	get_tree().quit(0 if report.failed_check_count == 0 else 1)


func _find_test_file_names() -> Array[String]:
	var test_file_names: Array[String] = []
	for file_name in DirAccess.get_files_at(TESTS_FOLDER_PATH):
		if file_name.begins_with(TEST_FILE_PREFIX) and file_name.ends_with(TEST_FILE_SUFFIX):
			test_file_names.append(file_name)
	test_file_names.sort()
	return test_file_names
