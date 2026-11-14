class_name TestReport
extends RefCounted
## Collects the results of the checks made by the files in res://tests.
## Each test file receives one TestReport in its run_tests function.

var passed_check_count: int = 0
var failed_check_count: int = 0
var failure_descriptions: Array[String] = []


## Records one check. The description should say what is expected to be true.
func check(is_condition_true: bool, description: String) -> void:
	if is_condition_true:
		passed_check_count += 1
		print("  PASS  ", description)
	else:
		failed_check_count += 1
		failure_descriptions.append(description)
		print("  FAIL  ", description)


## Checks that a number is within the given tolerance of the expected number.
func check_close(actual_value: float, expected_value: float, tolerance: float, description: String) -> void:
	var difference: float = absf(actual_value - expected_value)
	var full_description := "%s (expected %s, got %s, tolerance %s)" % [
			description, expected_value, actual_value, tolerance]
	check(difference <= tolerance, full_description)
