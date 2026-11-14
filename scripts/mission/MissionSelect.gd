extends Control
## Mission briefing and explicit science/quest choices, committed on acceptance.

var _chosen_mission: Dictionary = {}
var _chosen_science_id := ""
var _chosen_quest_ids: Array[String] = []
var _mission_contents: VBoxContainer
var _details_contents: VBoxContainer
var _accept_button: Button
var _budget_label: Label
var _mission_buttons: Array[Button] = []

func _ready() -> void:
	theme = MissionPresentation.create_theme()
	MissionPresentation.add_background(self)
	var heading := MissionPresentation.add_label(self, "MISSION ASSIGNMENT", 20)
	heading.position = Vector2(16, 8)
	heading.size = Vector2(490, 28)
	_mission_contents = MissionPresentation.add_monitor(self, Rect2(12, 44, 174, 300))
	_details_contents = MissionPresentation.add_monitor(self, Rect2(194, 44, 434, 300))
	MissionPresentation.add_label(_mission_contents, "1 / MISSION", 16)
	for mission in GameData.all_missions():
		var button := Button.new()
		button.text = "%s\n%.0f million USD" % [mission.get("name", "Mission"), float(mission.get("budget_million_usd", 0.0))]
		button.toggle_mode = true
		button.pressed.connect(_on_mission_chosen.bind(mission))
		_mission_contents.add_child(button)
		_mission_buttons.append(button)
	MissionPresentation.add_label(_details_contents, "Choose a mission card to read its briefing.")
	_budget_label = MissionPresentation.add_label(self, "Choose a mission and one science objective.")
	_budget_label.position = Vector2(16, 354)
	_budget_label.size = Vector2(370, 38)
	_accept_button = Button.new()
	_accept_button.text = "Accept mission"
	_accept_button.position = Vector2(426, 354)
	_accept_button.size = Vector2(202, 34)
	_accept_button.disabled = true
	_accept_button.pressed.connect(_accept_mission)
	add_child(_accept_button)

func _on_mission_chosen(mission: Dictionary) -> void:
	_chosen_mission = mission
	_chosen_science_id = ""
	_chosen_quest_ids.clear()
	var missions := GameData.all_missions()
	for mission_index in _mission_buttons.size():
		_mission_buttons[mission_index].set_pressed_no_signal(missions[mission_index].get("id") == mission.get("id"))
	_redraw_details()
	_update_acceptance()

func _redraw_details() -> void:
	MissionPresentation.clear_contents(_details_contents)
	MissionPresentation.add_label(_details_contents, _chosen_mission.get("name", "Mission"), 18)
	MissionPresentation.add_label(_details_contents, _chosen_mission.get("briefing", ""))
	var target: Dictionary = _chosen_mission.get("target", {})
	MissionPresentation.add_label(_details_contents, "TARGET  %.0f +/- %.0f km; eccentricity %.3f +/- %.3f\nDURATION  %.0f seconds\nBASE BUDGET  %.2f million USD" % [
		float(target.get("altitude_kilometers", 0.0)), float(target.get("altitude_tolerance_kilometers", 0.0)),
		float(target.get("eccentricity", 0.0)), float(target.get("eccentricity_tolerance", 0.0)),
		float(_chosen_mission.get("duration_seconds", 0.0)), float(_chosen_mission.get("budget_million_usd", 0.0))])
	MissionPresentation.add_label(_details_contents, "REGIONAL HAZARDS (placeholder rates)", 15)
	var zones: Array = _chosen_mission.get("hazard_zones", [])
	if zones.is_empty():
		MissionPresentation.add_label(_details_contents, "No regional hazard zones listed.")
	for zone: Dictionary in zones:
		MissionPresentation.add_label(_details_contents, "%s: %s." % [zone.get("name", "Hazard"), MissionPresentation.zone_text(zone)])
	MissionPresentation.add_label(_details_contents, "2 / SCIENCE OBJECTIVE", 16)
	var science_group := ButtonGroup.new()
	for science: Dictionary in _chosen_mission.get("science_missions", []):
		var choice := CheckBox.new()
		choice.text = science.get("name", "Science")
		choice.button_group = science_group
		choice.set_pressed_no_signal(science.get("id", "") == _chosen_science_id)
		var instrument_descriptions: Array[String] = []
		for part in GameData.parts_in_category(GameData.CATEGORY_SCIENCE):
			var fit: Dictionary = part.get("mission_fit", {})
			var stars := int(fit.get(science.get("id", ""), 0))
			if stars > 0:
				instrument_descriptions.append("%s: %d/3 stars" % [part.get("name", "Instrument"), stars])
		choice.disabled = instrument_descriptions.is_empty()
		choice.toggled.connect(_on_science_toggled.bind(str(science.get("id", ""))))
		_details_contents.add_child(choice)
		MissionPresentation.add_label(_details_contents, "%s\nZONE  %s\nREQUIRED  %.0f%% coverage; %.0f megabits\nINSTRUMENT FIT  %s" % [
			science.get("description", ""), MissionPresentation.zone_text(science.get("zone", {})),
			100.0 * float(science.get("required_coverage_fraction", 0.0)), float(science.get("required_data_megabits", 0.0)),
			"Awaiting catalogue support; selection unavailable." if instrument_descriptions.is_empty() else "; ".join(instrument_descriptions)])
	MissionPresentation.add_label(_details_contents, "3 / OPTIONAL SIDE QUESTS", 16)
	for quest: Dictionary in _chosen_mission.get("side_quests", []):
		var choice := CheckBox.new()
		choice.text = quest.get("name", "Quest")
		choice.set_pressed_no_signal(_chosen_quest_ids.has(quest.get("id", "")))
		choice.toggled.connect(_on_quest_toggled.bind(str(quest.get("id", ""))))
		_details_contents.add_child(choice)
		var event_names: Array[String] = []
		for event_id: String in quest.get("related_event_type_ids", []):
			event_names.append(GameData.event_type(event_id).get("name", event_id))
		MissionPresentation.add_label(_details_contents, "%s\nGRANT  +%.2f million USD; SUCCESS  +20 points\nFAILURE  grant reclaimed; total penalty 5 / 15 / 30 for 1 / 2 / 3 failed quests\nRISK  %s x%.1f; other event rates +%.0f%%" % [
			quest.get("description", ""), float(quest.get("grant_million_usd", 0.0)), ", ".join(event_names),
			float(quest.get("related_multiplier", 1.0)), 100.0 * float(quest.get("unrelated_bonus", 0.0))])

func _on_science_toggled(is_selected: bool, science_id: String) -> void:
	if is_selected:
		_chosen_science_id = science_id
	_update_acceptance()

func _on_quest_toggled(is_selected: bool, quest_id: String) -> void:
	if is_selected and not _chosen_quest_ids.has(quest_id):
		_chosen_quest_ids.append(quest_id)
	elif not is_selected:
		_chosen_quest_ids.erase(quest_id)
	_update_acceptance()

func _update_acceptance() -> void:
	var budget_million_usd: float = _chosen_mission.get("budget_million_usd", 0.0)
	for quest: Dictionary in _chosen_mission.get("side_quests", []):
		if _chosen_quest_ids.has(quest.get("id", "")):
			budget_million_usd += float(quest.get("grant_million_usd", 0.0))
	_budget_label.text = "BUDGET  %.2f million USD\n%d side quests accepted" % [budget_million_usd, _chosen_quest_ids.size()]
	_accept_button.disabled = _chosen_mission.is_empty() or _chosen_science_id.is_empty()

func _accept_mission() -> void:
	if _accept_button.disabled:
		return
	GameState.select_mission(_chosen_mission["id"], _chosen_science_id, _chosen_quest_ids)
	GameState.go_to_scene(GameState.CONSOLE_SCENE_PATH)
