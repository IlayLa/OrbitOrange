extends Control
## Mission briefing and explicit science/quest choices, committed on acceptance.
##
## Laid out without text walls (design/minimize_text_walls_options.md, Options
## 2 and 3): three always-visible columns, MISSION | SCIENCE | QUESTS, and a
## live budget footer beside Accept.
##   MISSION   one card per mission, a two-line briefing, and an orbit
##             schematic of the target, the science band and the hazard belts
##   SCIENCE   one card per objective: band, coverage, data and fit stars;
##             an objective no instrument can serve is grey with a lock
##   QUESTS    the 5 / 15 / 30 failure penalty once, as pips that light up as
##             quests are ticked; one card per quest with its grant and risk
## Cards show at most two lines of text; the full text is in the tooltip.

const COLUMN_TOP_PIXELS := 30.0
const COLUMN_HEIGHT_PIXELS := 322.0
const COLUMN_WIDTH_PIXELS := 204.0
const COLUMN_LEFTS: Array[float] = [8.0, 218.0, 428.0]
const COLUMN_PADDING_PIXELS := 4.0
const HEADER_HEIGHT_PIXELS := 16.0
const QUEST_HEADER_HEIGHT_PIXELS := 30.0
const CARD_GAP_PIXELS := 4
const MISSION_CARD_LIST_MAXIMUM_HEIGHT_PIXELS := 102.0
const SCHEMATIC_HEIGHT_PIXELS := 140.0
const QUEST_PENALTY_POINTS: Array[int] = [5, 15, 30]
const QUEST_SUCCESS_POINTS := 20
const COLOR_HEADER := Color("ffd27a")
const COLOR_BAND_GLYPH := Color("7fb3d9")
const COLOR_PIP_OFF := Color("4a5568")

var _chosen_mission: Dictionary = {}
var _chosen_science_id := ""
var _chosen_quest_ids: Array[String] = []
var _mission_contents: VBoxContainer
## The science column's cards.
var _details_contents: VBoxContainer
var _quest_contents: VBoxContainer
var _accept_button: Button
var _budget_label: Label
var _mission_buttons: Array[Button] = []
var _briefing: Control
var _schematic: OrbitSchematic
var _schematic_legend: Control
var _quest_header: Control
var _science_header: Control


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = MissionPresentation.create_theme()
	MissionPresentation.add_background(self)
	var heading := MissionPresentation.add_label(self, "MISSION ASSIGNMENT", 16)
	heading.position = Vector2(10, 6)
	heading.size = Vector2(400, 22)

	_create_mission_column(_add_column(0))
	_science_header = _add_header(_add_column(1), "SCIENCE", "pick one")
	_details_contents = _add_card_list(_science_header.get_parent(), HEADER_HEIGHT_PIXELS)
	var quest_column: Control = _add_column(2)
	_quest_header = _add_header(quest_column, "QUESTS", "optional", QUEST_HEADER_HEIGHT_PIXELS)
	_quest_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_header.tooltip_text = "Each quest adds its grant to the budget. A failed quest gives the grant back. Failures cost 5, 15 or 30 points in total (not added up) for 1, 2 or 3 failed quests; the lit pip is the total if every ticked quest fails. A quest done earns 20 points."
	_quest_header.draw.connect(_draw_penalty_pips)
	_quest_contents = _add_card_list(quest_column, QUEST_HEADER_HEIGHT_PIXELS)
	_add_waiting_text(_details_contents)
	_add_waiting_text(_quest_contents)

	_budget_label = MissionPresentation.add_label(self, "", 12)
	_budget_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_budget_label.position = Vector2(12, 360)
	_budget_label.size = Vector2(406, 30)
	_budget_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_accept_button = Button.new()
	_accept_button.text = "Accept mission"
	_accept_button.tooltip_text = "Needs a mission and one science objective."
	_accept_button.position = Vector2(426, 358)
	_accept_button.size = Vector2(206, 34)
	_accept_button.disabled = true
	_accept_button.pressed.connect(_accept_mission)
	add_child(_accept_button)
	_update_acceptance()


func _on_mission_chosen(mission: Dictionary) -> void:
	_chosen_mission = mission
	_chosen_science_id = ""
	_chosen_quest_ids.clear()
	var missions := GameData.all_missions()
	for mission_index in _mission_buttons.size():
		var mission_card: ChoiceCard = _mission_buttons[mission_index]
		mission_card.set_chosen_quietly(missions[mission_index].get("id") == mission.get("id"))
	_redraw_details()
	_update_acceptance()


func _redraw_details() -> void:
	_briefing.queue_redraw()
	_schematic.show_mission(_chosen_mission, _chosen_science())
	_schematic_legend.queue_redraw()

	MissionPresentation.clear_contents(_details_contents)
	var card_width_pixels: float = _card_width_pixels()
	var science_group := ButtonGroup.new()
	science_group.allow_unpress = false
	for science: Dictionary in _chosen_mission.get("science_missions", []):
		var science_id: String = science.get("id", "")
		var fit_descriptions: Array[String] = []
		var best_fit_stars := 0
		for part in GameData.parts_in_category(GameData.CATEGORY_SCIENCE):
			var stars: int = PartDetailsPopup.mission_fit_stars(part, science_id)
			if stars > 0:
				fit_descriptions.append("%s %d/3" % [part.get("name", "Instrument"), stars])
				best_fit_stars = maxi(best_fit_stars, stars)
		var zone: Dictionary = science.get("zone", {})
		var chips: Array[Dictionary] = [
			{"glyph": "band", "text": _band_text(zone), "glyph_color": COLOR_BAND_GLYPH},
			{"glyph": "coverage", "text": "%d%%" % roundi(100.0 * float(science.get("required_coverage_fraction", 0.0)))},
			{"glyph": "data", "text": "%sMb" % NumberFormat.compact(float(science.get("required_data_megabits", 0.0)))},
		]
		var card := ChoiceCard.new()
		card.is_radio = true
		card.button_group = science_group
		card.fit_star_count = best_fit_stars
		card.setup(science.get("name", "Science"), science.get("description", ""), chips, card_width_pixels,
				"Instruments: " + (", ".join(fit_descriptions) if not fit_descriptions.is_empty() else "none rated yet; locked."))
		card.set_chosen_quietly(science_id == _chosen_science_id)
		card.set_locked(fit_descriptions.is_empty())
		card.toggled.connect(_on_science_toggled.bind(science_id))
		_details_contents.add_child(card)

	MissionPresentation.clear_contents(_quest_contents)
	for quest: Dictionary in _chosen_mission.get("side_quests", []):
		var event_names: Array[String] = []
		for event_id: String in quest.get("related_event_type_ids", []):
			event_names.append(GameData.event_type(event_id).get("name", event_id))
		var risk_text := "%s ×%s" % [
				event_names[0].get_slice(" ", 0) if not event_names.is_empty() else "events",
				NumberFormat.compact(float(quest.get("related_multiplier", 1.0)))]
		var chips: Array[Dictionary] = [
			{"glyph": "fuel", "text": quest_rule_text(quest.get("condition", {})), "glyph_color": COLOR_BAND_GLYPH},
			{"glyph": "money", "text": "+%s / −grant" % NumberFormat.money(float(quest.get("grant_million_usd", 0.0))),
				"glyph_color": PixelGlyphs.COLOR_GOOD_GREEN},
			{"glyph": "star", "text": "+%d" % QUEST_SUCCESS_POINTS, "glyph_color": ScreenLayout.COLOR_ACCENT_ORANGE},
			{"glyph": "risk", "text": risk_text, "glyph_color": PixelGlyphs.COLOR_AMBER},
		]
		var card := ChoiceCard.new()
		card.setup(quest.get("name", "Quest"), quest.get("description", ""), chips, card_width_pixels,
				"Risk: %s ×%s; other events +%d%%. Done: +%d points. Failed: grant reclaimed." % [
				", ".join(event_names), NumberFormat.compact(float(quest.get("related_multiplier", 1.0))),
				roundi(100.0 * float(quest.get("unrelated_bonus", 0.0))), QUEST_SUCCESS_POINTS])
		card.set_chosen_quietly(_chosen_quest_ids.has(quest.get("id", "")))
		card.toggled.connect(_on_quest_toggled.bind(str(quest.get("id", ""))))
		_quest_contents.add_child(card)
	if _chosen_mission.get("side_quests", []).is_empty():
		_add_waiting_text(_quest_contents, "No quests for this mission.")
	_quest_header.queue_redraw()


## The index of the one penalty pip to light for this many ticked quests,
## or -1 with none ticked. Penalties are totals, so one pip is the whole risk.
static func lit_penalty_pip_index(ticked_quest_count: int) -> int:
	if ticked_quest_count <= 0:
		return -1
	return mini(ticked_quest_count, QUEST_PENALTY_POINTS.size()) - 1


## The quest's rule as a chip, so that it is never cut from the card:
## "reserve ≥100m/s" or "reserve ≤10m/s".
static func quest_rule_text(condition: Dictionary) -> String:
	var threshold_text := NumberFormat.meters_per_second(float(condition.get("delta_v_meters_per_second", 0.0)))
	match condition.get("type", ""):
		"reserve_delta_v_at_least":
			return "end reserve ≥" + threshold_text
		"reserve_delta_v_at_most":
			return "end reserve ≤" + threshold_text
	return "see tooltip"


func _on_science_toggled(is_selected: bool, science_id: String) -> void:
	if is_selected:
		_chosen_science_id = science_id
		_schematic.show_mission(_chosen_mission, _chosen_science())
		_schematic_legend.queue_redraw()
	_update_acceptance()


func _on_quest_toggled(is_selected: bool, quest_id: String) -> void:
	if is_selected and not _chosen_quest_ids.has(quest_id):
		_chosen_quest_ids.append(quest_id)
	elif not is_selected:
		_chosen_quest_ids.erase(quest_id)
	_quest_header.queue_redraw()
	_update_acceptance()


func _update_acceptance() -> void:
	var base_budget_million_usd: float = _chosen_mission.get("budget_million_usd", 0.0)
	var grants_million_usd := 0.0
	for quest: Dictionary in _chosen_mission.get("side_quests", []):
		if _chosen_quest_ids.has(quest.get("id", "")):
			grants_million_usd += float(quest.get("grant_million_usd", 0.0))
	if _chosen_mission.is_empty():
		_budget_label.text = "BUDGET  --"
	elif grants_million_usd > 0.0:
		_budget_label.text = "BUDGET  %s   = %s + %s grants" % [NumberFormat.money(base_budget_million_usd + grants_million_usd),
				NumberFormat.money(base_budget_million_usd), NumberFormat.money(grants_million_usd)]
	else:
		_budget_label.text = "BUDGET  %s" % NumberFormat.money(base_budget_million_usd)
	_accept_button.disabled = _chosen_mission.is_empty() or _chosen_science_id.is_empty()


func _accept_mission() -> void:
	if _accept_button.disabled:
		return
	GameState.select_mission(_chosen_mission["id"], _chosen_science_id, _chosen_quest_ids)
	GameState.go_to_scene(GameState.CONSOLE_SCENE_PATH)


func _chosen_science() -> Dictionary:
	for science: Dictionary in _chosen_mission.get("science_missions", []):
		if science.get("id", "") == _chosen_science_id:
			return science
	return {}


func _card_width_pixels() -> float:
	return COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS - 8.0


static func _band_text(zone: Dictionary) -> String:
	return "%s–%s" % [NumberFormat.compact(float(zone.get("inner_altitude_kilometers", 0.0))),
			NumberFormat.kilometers(float(zone.get("outer_altitude_kilometers", 0.0)))]


## A black monitor for one column; returns it.
func _add_column(column_index: int) -> Control:
	var column := Panel.new()
	column.position = Vector2(COLUMN_LEFTS[column_index], COLUMN_TOP_PIXELS)
	column.size = Vector2(COLUMN_WIDTH_PIXELS, COLUMN_HEIGHT_PIXELS)
	var style := StyleBoxFlat.new()
	style.bg_color = ScreenLayout.COLOR_SPACE_BLACK
	style.border_color = ScreenLayout.COLOR_MONITOR_FRAME
	style.set_border_width_all(2)
	column.add_theme_stylebox_override("panel", style)
	add_child(column)
	return column


## A drawn header: the column name and a muted note on the right.
func _add_header(column: Control, title: String, note: String, height_pixels: float = HEADER_HEIGHT_PIXELS) -> Control:
	var header := Control.new()
	header.position = Vector2(COLUMN_PADDING_PIXELS, 2)
	header.size = Vector2(COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS, height_pixels - 2.0)
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.draw.connect(func() -> void:
		PixelGlyphs.draw_text(header, Vector2(0, 1), title, COLOR_HEADER, PixelGlyphs.TITLE_SIZE_PIXELS)
		var note_width: float = PixelGlyphs.text_width(note)
		PixelGlyphs.draw_text(header, Vector2(header.size.x - note_width, 2), note, PixelGlyphs.COLOR_MUTED_TEXT)
		header.draw_line(Vector2(0, 13), Vector2(header.size.x, 13), Color(COLOR_HEADER, 0.4), 1.0))
	column.add_child(header)
	return header


## A scrolling list of cards below a header of the given height.
func _add_card_list(column: Control, top_pixels: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(COLUMN_PADDING_PIXELS, top_pixels + 2.0)
	scroll.size = Vector2(COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS, COLUMN_HEIGHT_PIXELS - top_pixels - 6.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", CARD_GAP_PIXELS)
	scroll.add_child(contents)
	return contents


func _add_waiting_text(contents: Control, text: String = "Pick a mission first.") -> void:
	var waiting := MissionPresentation.add_label(contents, text, 8)
	waiting.add_theme_color_override("font_color", PixelGlyphs.COLOR_MUTED_TEXT)


func _create_mission_column(column: Control) -> void:
	_add_header(column, "MISSION", "pick one")
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(COLUMN_PADDING_PIXELS, HEADER_HEIGHT_PIXELS + 2.0)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_mission_contents = VBoxContainer.new()
	_mission_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_contents.add_theme_constant_override("separation", CARD_GAP_PIXELS)
	scroll.add_child(_mission_contents)
	var mission_group := ButtonGroup.new()
	mission_group.allow_unpress = false
	var list_height_pixels := 0.0
	for mission in GameData.all_missions():
		var card := ChoiceCard.new()
		card.is_radio = true
		card.button_group = mission_group
		var chips: Array[Dictionary] = [
			{"glyph": "money", "text": NumberFormat.money(float(mission.get("budget_million_usd", 0.0))), "glyph_color": PixelGlyphs.COLOR_GOOD_GREEN},
			{"glyph": "clock", "text": NumberFormat.duration(float(mission.get("duration_seconds", 0.0)))},
			{"glyph": "target", "text": NumberFormat.kilometers(float(mission.get("target", {}).get("altitude_kilometers", 0.0))),
				"glyph_color": PixelGlyphs.COLOR_GOOD_GREEN},
		]
		card.setup(mission.get("name", "Mission"), "", chips, _card_width_pixels(), PixelGlyphs.without_placeholder_prefix(mission.get("briefing", "")))
		card.pressed.connect(_on_mission_chosen.bind(mission))
		_mission_contents.add_child(card)
		_mission_buttons.append(card)
		list_height_pixels += card.custom_minimum_size.y + CARD_GAP_PIXELS
	var shown_list_height_pixels: float = minf(list_height_pixels, MISSION_CARD_LIST_MAXIMUM_HEIGHT_PIXELS)
	scroll.size = Vector2(COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS, shown_list_height_pixels)
	var next_top: float = scroll.position.y + shown_list_height_pixels + 1.0

	_briefing = Control.new()
	_briefing.position = Vector2(COLUMN_PADDING_PIXELS, next_top)
	_briefing.size = Vector2(COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS, 2.0 * PixelGlyphs.LINE_HEIGHT_PIXELS + 2.0)
	_briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing.draw.connect(_draw_briefing)
	column.add_child(_briefing)
	next_top += _briefing.size.y + 2.0

	_schematic = OrbitSchematic.new()
	_schematic.position = Vector2(COLUMN_PADDING_PIXELS, next_top)
	_schematic.size = Vector2(COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS, SCHEMATIC_HEIGHT_PIXELS)
	_schematic.clip_contents = true
	_schematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_schematic)
	next_top += SCHEMATIC_HEIGHT_PIXELS + 2.0

	_schematic_legend = Control.new()
	_schematic_legend.position = Vector2(COLUMN_PADDING_PIXELS, next_top)
	_schematic_legend.size = Vector2(COLUMN_WIDTH_PIXELS - 2.0 * COLUMN_PADDING_PIXELS, COLUMN_HEIGHT_PIXELS - next_top - 3.0)
	_schematic_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_schematic_legend.clip_contents = true
	_schematic_legend.draw.connect(_draw_schematic_legend)
	column.add_child(_schematic_legend)


## Two lines of briefing, cut by the layout; the full text is the card's tooltip.
func _draw_briefing() -> void:
	if _chosen_mission.is_empty():
		PixelGlyphs.draw_text(_briefing, Vector2(0, 0), "Pick a mission card.", PixelGlyphs.COLOR_MUTED_TEXT)
		return
	var briefing: String = _chosen_mission.get("briefing", "")
	var lines: Array[String] = PixelGlyphs.wrap_lines(PixelGlyphs.without_placeholder_prefix(briefing), _briefing.size.x, 2)
	for line_index in lines.size():
		PixelGlyphs.draw_text(_briefing, Vector2(0, line_index * PixelGlyphs.LINE_HEIGHT_PIXELS), lines[line_index], ScreenLayout.COLOR_TEXT_LIGHT)


## The key of the schematic, one row each: target, science band, hazards.
func _draw_schematic_legend() -> void:
	if _chosen_mission.is_empty():
		return
	var target: Dictionary = _chosen_mission.get("target", {})
	var row_top := 0.0
	PixelGlyphs.draw_chip(_schematic_legend, Vector2(0, row_top), "target", "target %s ±%s" % [
			NumberFormat.kilometers(float(target.get("altitude_kilometers", 0.0))),
			NumberFormat.kilometers(float(target.get("altitude_tolerance_kilometers", 0.0)))], PixelGlyphs.COLOR_GOOD_GREEN)
	row_top += 10.0
	var science := _chosen_science()
	if science.is_empty() and not _chosen_mission.get("science_missions", []).is_empty():
		science = _chosen_mission["science_missions"][0]
	if not science.is_empty():
		PixelGlyphs.draw_chip(_schematic_legend, Vector2(0, row_top), "band", "science %s" % _band_text(science.get("zone", {})), COLOR_BAND_GLYPH)
		row_top += 10.0
	# Room for the zone text: the row less the hazard glyph and the badge.
	var text_room: float = (_schematic_legend.size.x - PixelGlyphs.chip_width("hazard", "")
			- 4.0 - PixelGlyphs.placeholder_badge_width())
	for zone: Dictionary in _chosen_mission.get("hazard_zones", []):
		var zone_name := str(zone.get("name", "hazard")).to_lower()
		var zone_text := "%s %s" % [zone_name, _band_text(zone)]
		if _schematic.is_beyond_diagram(zone):
			var inner_text := NumberFormat.kilometers(float(zone.get("inner_altitude_kilometers", 0.0)))
			zone_text = "%s >%s, off chart" % [zone_name, inner_text]
			# ">" already says the zone is above the chart; drop the words when they do not fit.
			if PixelGlyphs.text_width(zone_text) > text_room:
				zone_text = "%s >%s" % [zone_name, inner_text]
		zone_text = PixelGlyphs.fit_to_width(zone_text, text_room)
		var used_width: float = PixelGlyphs.draw_chip(_schematic_legend, Vector2(0, row_top), "hazard",
				zone_text, ScreenLayout.COLOR_WARNING_RED)
		PixelGlyphs.draw_placeholder_badge(_schematic_legend, Vector2(used_width + 4.0, row_top))
		row_top += 10.0


## "if all fail" and one pip per penalty step. The penalties are totals
## (5, 15 or 30 points for 1, 2 or 3 failed quests), so only the pip for the
## number of quests ticked is lit (filled amber, dark number); the others are
## outlines with a grey number.
func _draw_penalty_pips() -> void:
	var row_top := 16.0
	var next_left: float = PixelGlyphs.draw_text(_quest_header, Vector2(0, row_top), "if all fail", PixelGlyphs.COLOR_MUTED_TEXT) + 4.0
	for penalty_index in QUEST_PENALTY_POINTS.size():
		var penalty_text := "−%d" % QUEST_PENALTY_POINTS[penalty_index]
		var pip_rect := Rect2(Vector2(next_left, row_top), Vector2(PixelGlyphs.text_width(penalty_text) + 6.0, 10.0))
		var is_lit: bool = penalty_index == lit_penalty_pip_index(_chosen_quest_ids.size())
		if is_lit:
			_quest_header.draw_rect(pip_rect, PixelGlyphs.COLOR_AMBER)
			PixelGlyphs.draw_text(_quest_header, pip_rect.position + Vector2(3, 0), penalty_text, PixelGlyphs.COLOR_OUTLINE)
		else:
			_quest_header.draw_rect(pip_rect.grow(-0.5), COLOR_PIP_OFF, false, 1.0)
			PixelGlyphs.draw_text(_quest_header, pip_rect.position + Vector2(3, 0), penalty_text, COLOR_PIP_OFF)
		next_left = pip_rect.end.x + 3.0
	PixelGlyphs.draw_text(_quest_header, Vector2(next_left + 1.0, row_top), "pts", PixelGlyphs.COLOR_MUTED_TEXT)
