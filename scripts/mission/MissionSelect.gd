extends Control
## The player picks a mission, one science mission and optional side quests,
## then accepts. Requirements: context/plan_draft.md, section "Game flow".
##
## STUB(T04): lists the missions as plain buttons, always takes the first
## science mission and no side quests. T04 replaces this file.


func _ready() -> void:
	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_BEZEL_DARK
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)

	var heading_label := Label.new()
	heading_label.text = "SELECT A MISSION (stub screen)"
	heading_label.position = Vector2(20, 12)
	add_child(heading_label)

	var next_button_position_y_pixels := 50.0
	for mission in GameData.all_missions():
		var mission_button := Button.new()
		mission_button.text = "%s  (budget %s million USD)" % [
				mission.get("name", "?"), mission.get("budget_million_usd", 0)]
		mission_button.position = Vector2(20, next_button_position_y_pixels)
		mission_button.size = Vector2(400, 32)
		mission_button.pressed.connect(_on_mission_chosen.bind(mission))
		add_child(mission_button)
		next_button_position_y_pixels += 40.0


func _on_mission_chosen(mission: Dictionary) -> void:
	var first_science_mission_id := ""
	var science_missions: Array = mission.get("science_missions", [])
	if not science_missions.is_empty():
		first_science_mission_id = science_missions[0].get("id", "")
	var no_side_quest_ids: Array[String] = []

	GameState.select_mission(mission.get("id", ""), first_science_mission_id, no_side_quest_ids)
	GameState.go_to_scene(GameState.CONSOLE_SCENE_PATH)
