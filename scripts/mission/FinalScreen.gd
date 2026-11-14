extends Control
## The final screen: the score band, the score table with one explanation per
## line, and the event log. It reads GameState.score and GameState.flight_result.
## Requirements: context/plan_draft.md, section "Scoring".
##
## STUB(T04): prints the score lines as plain text. T04 replaces this file.


func _ready() -> void:
	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_SPACE_BLACK
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)

	var report_label := Label.new()
	report_label.position = Vector2(20, 20)
	report_label.size = Vector2(600, 300)
	report_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report_label.text = _describe_score(GameState.score)
	add_child(report_label)

	var main_menu_button := Button.new()
	main_menu_button.text = "Back to main menu"
	main_menu_button.position = Vector2(20, 350)
	main_menu_button.size = Vector2(180, 32)
	main_menu_button.pressed.connect(GameState.go_to_scene.bind(GameState.MAIN_MENU_SCENE_PATH))
	add_child(main_menu_button)


func _describe_score(score: ScoreReport) -> String:
	if score == null:
		return "No flight has been scored yet."
	if score.is_launch_failure:
		return "Rocket didn't launch successfully.\nScore: 0"
	var report_text := "MISSION RESULT (stub screen)\n%s: %.0f points\n" % [score.band_name, score.total_points]
	for line in score.lines:
		report_text += "\n%s / %s: %.0f of %.0f. %s" % [
				line.part_name, line.line_name, line.points, line.maximum_points, line.explanation]
	return report_text
