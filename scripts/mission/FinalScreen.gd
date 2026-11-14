extends Control
## Displays the scored result and flight log; also works without an active run.

const PORTRAIT_PATHS := {
	"Failure": "res://assets/placeholders/portraits/failure.png",
	"Partial Success": "res://assets/placeholders/portraits/partial_success.png",
	"Success": "res://assets/placeholders/portraits/success.png",
	"Great Success": "res://assets/placeholders/portraits/great_success.png",
	"Perfect": "res://assets/placeholders/portraits/perfect.png",
	"Scientific Breakthrough": "res://assets/placeholders/portraits/scientific_breakthrough.png",
}
var _score_contents: VBoxContainer
var _event_contents: VBoxContainer

func _ready() -> void:
	theme = MissionPresentation.create_theme()
	MissionPresentation.add_background(self)
	var score := GameState.score
	var result := GameState.flight_result
	var portrait := TextureRect.new()
	portrait.position = Vector2(16, 12)
	portrait.size = Vector2(72, 72)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	portrait.texture = load(PORTRAIT_PATHS.get(score.band_name if score != null else "Failure", PORTRAIT_PATHS["Failure"]))
	add_child(portrait)
	var heading := MissionPresentation.add_label(self, "MISSION REPORT", 20)
	heading.position = Vector2(102, 10)
	heading.size = Vector2(400, 28)
	var status := MissionPresentation.add_label(self, _status_text(score, result), 16)
	status.position = Vector2(102, 40)
	status.size = Vector2(510, 64)
	var score_button := Button.new()
	score_button.text = "Score breakdown"
	score_button.position = Vector2(12, 110)
	score_button.size = Vector2(200, 30)
	add_child(score_button)
	var events_button := Button.new()
	events_button.text = "Flight event log"
	events_button.position = Vector2(220, 110)
	events_button.size = Vector2(200, 30)
	add_child(events_button)
	_score_contents = MissionPresentation.add_monitor(self, Rect2(12, 148, 616, 196))
	_event_contents = MissionPresentation.add_monitor(self, Rect2(12, 148, 616, 196))
	var score_panel := _score_contents.get_parent().get_parent() as Control
	var event_panel := _event_contents.get_parent().get_parent() as Control
	event_panel.hide()
	score_button.pressed.connect(func() -> void: score_panel.show(); event_panel.hide())
	events_button.pressed.connect(func() -> void: score_panel.hide(); event_panel.show())
	_add_score_rows(score)
	_add_event_rows(result)
	var menu_button := Button.new()
	menu_button.text = "Back to main menu"
	menu_button.position = Vector2(426, 354)
	menu_button.size = Vector2(202, 34)
	menu_button.pressed.connect(GameState.go_to_scene.bind(GameState.MAIN_MENU_SCENE_PATH))
	add_child(menu_button)

func _status_text(score: ScoreReport, result: FlightResult) -> String:
	if score == null:
		return "No flight has been scored yet."
	if score.is_launch_failure:
		return "Rocket didn't launch successfully\nScore: 0"
	var reason := "Flight result unavailable"
	if result != null:
		reason = str(FlightResult.EndReason.keys()[result.end_reason]).replace("_", " ").capitalize()
	return "%s / %.4f points\n%s" % [score.band_name, score.total_points, reason]

func _add_score_rows(score: ScoreReport) -> void:
	if score == null:
		MissionPresentation.add_label(_score_contents, "Complete a flight to see its score breakdown.")
		return
	if score.is_launch_failure:
		MissionPresentation.add_label(_score_contents, "Launch failure overrides every score component: 0 points.")
		return
	var previous_part := ""
	for line in score.lines:
		if line.part_name != previous_part:
			MissionPresentation.add_label(_score_contents, line.part_name.to_upper(), 16)
			previous_part = line.part_name
		var label := MissionPresentation.add_label(_score_contents, "%s   %.4f / %.0f points\n%s" % [line.line_name, line.points, line.maximum_points, line.explanation])
		if line.points < 0.0:
			label.add_theme_color_override("font_color", ScreenLayout.COLOR_WARNING_RED)

func _add_event_rows(result: FlightResult) -> void:
	if result == null or result.event_log.is_empty():
		MissionPresentation.add_label(_event_contents, "No flight events recorded.")
		return
	MissionPresentation.add_label(_event_contents, "Events are informational; avoidance earns no direct bonus.")
	for event in result.event_log:
		var event_id: String = event.get("event_type_id", "unknown")
		var event_name: String = GameData.event_type(event_id).get("name", event_id)
		MissionPresentation.add_label(_event_contents, "%.1f s / %s / %s\nReaction: %s; delta-v spent: %.2f m/s\n%s" % [
			float(event.get("time_seconds", 0.0)), event_name, event.get("outcome", "Unrecorded"),
			"reacted" if event.get("did_player_react", false) else "observed", float(event.get("delta_v_spent_meters_per_second", 0.0)),
			event.get("explanation", "No explanation supplied.")])
