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
##
## The background is the mock-up design/mission_choice.png (copied to
## ScreenLayout.MISSION_SELECT_BACKGROUND_PATH): it draws the three panels,
## the rule under each title and the boxes the first cards sit in. The
## rectangles are in ScreenLayout, in mock-up pixels times five.

## Gap between cards: the one-pixel gap between the mock-up's mission boxes.
const CARD_GAP_PIXELS := 5
## Space left under the mission boxes for the briefing.
const BRIEFING_TOP_GAP_PIXELS := 5.0
const SCHEMATIC_HEIGHT_PIXELS := 110.0
## Where the title text sits in its row: just above the mock-up's rule.
const TITLE_TOP_IN_ROW_PIXELS := 21.0
## Budget and Accept sit at the bottom of the Quests panel.
const BUDGET_SCREEN := Rect2(435, 314, 170, 16)
const ACCEPT_BUTTON_SCREEN := Rect2(435, 332, 170, 33)
## Space kept free below each scrolling list.
const LIST_BOTTOM_GAP_PIXELS := 4.0
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
## The "if all fail" pips, in the short box at the top of the Quests panel.
var _penalty_pips: Control
var _science_header: Control


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = MissionPresentation.create_theme()
	_add_background()

	var mission_column: Control = _add_column(0)
	_add_header(mission_column, 0, "MISSION", "pick one")
	_create_mission_column(mission_column)

	var science_column: Control = _add_column(1)
	_science_header = _add_header(science_column, 1, "SCIENCE", "pick one")
	_details_contents = _add_card_list(science_column, ScreenLayout.MISSION_SELECT_SCIENCE_CARD_BOX,
			ScreenLayout.MISSION_SELECT_PANEL_SCREENS[1].end.y - LIST_BOTTOM_GAP_PIXELS)

	var quest_column: Control = _add_column(2)
	var quest_tooltip := "Each quest adds its grant to the budget. A failed quest gives the grant back. Failures cost 5, 15 or 30 points in total (not added up) for 1, 2 or 3 failed quests; the lit pip is the total if every ticked quest fails. A quest done earns 20 points."
	_quest_header = _add_header(quest_column, 2, "QUESTS", "optional")
	_quest_header.mouse_filter = Control.MOUSE_FILTER_STOP
	_quest_header.tooltip_text = quest_tooltip
	_penalty_pips = Control.new()
	_place(_penalty_pips, quest_column, ScreenLayout.MISSION_SELECT_QUEST_PENALTY_BOX)
	_penalty_pips.tooltip_text = quest_tooltip
	_penalty_pips.draw.connect(_draw_penalty_pips)
	quest_column.add_child(_penalty_pips)
	_quest_contents = _add_card_list(quest_column, ScreenLayout.MISSION_SELECT_QUEST_CARD_BOX,
			BUDGET_SCREEN.position.y - LIST_BOTTOM_GAP_PIXELS)
	_add_waiting_text(_details_contents, ScreenLayout.MISSION_SELECT_SCIENCE_CARD_BOX.size.y)
	_add_waiting_text(_quest_contents, ScreenLayout.MISSION_SELECT_QUEST_CARD_BOX.size.y)

	_budget_label = MissionPresentation.add_label(self, "", 12)
	_budget_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	_budget_label.position = BUDGET_SCREEN.position
	_budget_label.size = BUDGET_SCREEN.size
	_budget_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_accept_button = Button.new()
	_accept_button.text = "Accept mission"
	_accept_button.tooltip_text = "Needs a mission and one science objective."
	_accept_button.position = ACCEPT_BUTTON_SCREEN.position
	_accept_button.size = ACCEPT_BUTTON_SCREEN.size
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
	var science_box: Rect2 = ScreenLayout.MISSION_SELECT_SCIENCE_CARD_BOX
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
		card.setup(science.get("name", "Science"), science.get("description", ""), chips, science_box.size.x,
				"Instruments: " + (", ".join(fit_descriptions) if not fit_descriptions.is_empty() else "none rated yet; locked."))
		card.set_chosen_quietly(science_id == _chosen_science_id)
		card.set_locked(fit_descriptions.is_empty())
		card.toggled.connect(_on_science_toggled.bind(science_id))
		_fill_box_height(card, science_box)
		_details_contents.add_child(card)

	MissionPresentation.clear_contents(_quest_contents)
	var quest_box: Rect2 = ScreenLayout.MISSION_SELECT_QUEST_CARD_BOX
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
		card.setup(quest.get("name", "Quest"), quest.get("description", ""), chips, quest_box.size.x,
				"Risk: %s ×%s; other events +%d%%. Done: +%d points. Failed: grant reclaimed." % [
				", ".join(event_names), NumberFormat.compact(float(quest.get("related_multiplier", 1.0))),
				roundi(100.0 * float(quest.get("unrelated_bonus", 0.0))), QUEST_SUCCESS_POINTS])
		card.set_chosen_quietly(_chosen_quest_ids.has(quest.get("id", "")))
		card.toggled.connect(_on_quest_toggled.bind(str(quest.get("id", ""))))
		_fill_box_height(card, quest_box)
		_quest_contents.add_child(card)
	if _chosen_mission.get("side_quests", []).is_empty():
		_add_waiting_text(_quest_contents, quest_box.size.y, "No quests for this mission.")
	_penalty_pips.queue_redraw()


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
	_penalty_pips.queue_redraw()
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


## Stretches a card to at least the height of the mock-up box it covers, so
## that no part of the box shows below a short card.
static func _fill_box_height(card: ChoiceCard, box: Rect2) -> void:
	card.custom_minimum_size.y = maxf(card.custom_minimum_size.y, box.size.y)


static func _band_text(zone: Dictionary) -> String:
	return "%s–%s" % [NumberFormat.compact(float(zone.get("inner_altitude_kilometers", 0.0))),
			NumberFormat.kilometers(float(zone.get("outer_altitude_kilometers", 0.0)))]


## The mock-up, stretched to the 640 x 400 canvas with nearest filtering.
func _add_background() -> void:
	var background := TextureRect.new()
	background.name = "MissionChoiceBackground"
	background.texture = load(ScreenLayout.MISSION_SELECT_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.size = ScreenLayout.SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)


## An empty holder over the inside of one of the mock-up's panels; returns it.
## The mock-up draws the panel, so the holder draws nothing.
func _add_column(column_index: int) -> Control:
	var column := Control.new()
	var panel_screen: Rect2 = ScreenLayout.MISSION_SELECT_PANEL_SCREENS[column_index]
	column.position = panel_screen.position
	column.size = panel_screen.size
	column.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(column)
	return column


## Puts a child of the column on a rectangle given in screen pixels.
static func _place(control: Control, column: Control, screen_rect: Rect2) -> void:
	control.position = screen_rect.position - column.position
	control.size = screen_rect.size


## A drawn header on the panel's title row: the column name and a muted note
## on the right, just above the mock-up's rule.
func _add_header(column: Control, column_index: int, title: String, note: String) -> Control:
	var header := Control.new()
	_place(header, column, ScreenLayout.MISSION_SELECT_TITLE_ROWS[column_index])
	header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	header.draw.connect(func() -> void:
		PixelGlyphs.draw_text(header, Vector2(0, TITLE_TOP_IN_ROW_PIXELS), title, COLOR_HEADER, PixelGlyphs.TITLE_SIZE_PIXELS)
		var note_width: float = PixelGlyphs.text_width(note)
		PixelGlyphs.draw_text(header, Vector2(header.size.x - note_width, TITLE_TOP_IN_ROW_PIXELS + 1.0), note, PixelGlyphs.COLOR_MUTED_TEXT))
	column.add_child(header)
	return header


## A scrolling list of cards whose first card covers first_box (screen
## pixels); the list runs down to bottom_pixels (screen pixels).
func _add_card_list(column: Control, first_box: Rect2, bottom_pixels: float) -> VBoxContainer:
	var scroll := ScrollContainer.new()
	_place(scroll, column, Rect2(first_box.position, Vector2(first_box.size.x, bottom_pixels - first_box.position.y)))
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", CARD_GAP_PIXELS)
	scroll.add_child(contents)
	return contents


## Muted text centred in the (still empty) first box of a list.
func _add_waiting_text(contents: Control, box_height_pixels: float, text: String = "Pick a mission first.") -> void:
	var waiting := MissionPresentation.add_label(contents, text, 8)
	waiting.add_theme_color_override("font_color", PixelGlyphs.COLOR_MUTED_TEXT)
	waiting.custom_minimum_size.y = box_height_pixels
	waiting.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	waiting.vertical_alignment = VERTICAL_ALIGNMENT_CENTER


## The mission cards in the mock-up's mission boxes, then the briefing, the
## orbit schematic and its key down to the bottom of the panel.
func _create_mission_column(column: Control) -> void:
	var boxes: Array[Rect2] = ScreenLayout.MISSION_SELECT_MISSION_CARD_BOXES
	var list_screen := Rect2(boxes[0].position, Vector2(boxes[0].size.x, boxes[boxes.size() - 1].end.y - boxes[0].position.y))
	var scroll := ScrollContainer.new()
	_place(scroll, column, list_screen)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_mission_contents = VBoxContainer.new()
	_mission_contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_mission_contents.add_theme_constant_override("separation", CARD_GAP_PIXELS)
	scroll.add_child(_mission_contents)
	var mission_group := ButtonGroup.new()
	mission_group.allow_unpress = false
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
		card.setup(mission.get("name", "Mission"), "", chips, boxes[0].size.x, PixelGlyphs.without_placeholder_prefix(mission.get("briefing", "")))
		_fill_box_height(card, boxes[0])
		card.pressed.connect(_on_mission_chosen.bind(mission))
		_mission_contents.add_child(card)
		_mission_buttons.append(card)

	var panel_screen: Rect2 = ScreenLayout.MISSION_SELECT_PANEL_SCREENS[0]
	var content_left: float = list_screen.position.x
	var content_width: float = list_screen.size.x
	var next_top: float = list_screen.end.y + BRIEFING_TOP_GAP_PIXELS

	_briefing = Control.new()
	_place(_briefing, column, Rect2(content_left, next_top, content_width, 2.0 * PixelGlyphs.LINE_HEIGHT_PIXELS + 2.0))
	_briefing.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_briefing.draw.connect(_draw_briefing)
	column.add_child(_briefing)
	next_top += _briefing.size.y + 2.0

	_schematic = OrbitSchematic.new()
	_place(_schematic, column, Rect2(content_left, next_top, content_width, SCHEMATIC_HEIGHT_PIXELS))
	_schematic.clip_contents = true
	_schematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	column.add_child(_schematic)
	next_top += SCHEMATIC_HEIGHT_PIXELS + 2.0

	_schematic_legend = Control.new()
	_place(_schematic_legend, column, Rect2(content_left, next_top, content_width, panel_screen.end.y - next_top - 3.0))
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
	for zone: Dictionary in _chosen_mission.get("hazard_zones", []):
		var zone_text := "%s %s" % [str(zone.get("name", "hazard")).to_lower(), _band_text(zone)]
		if _schematic.is_beyond_diagram(zone):
			zone_text = "%s >%s, off chart" % [str(zone.get("name", "hazard")).to_lower(),
					NumberFormat.kilometers(float(zone.get("inner_altitude_kilometers", 0.0)))]
		var used_width: float = PixelGlyphs.draw_chip(_schematic_legend, Vector2(0, row_top), "hazard",
				zone_text, ScreenLayout.COLOR_WARNING_RED)
		PixelGlyphs.draw_placeholder_badge(_schematic_legend, Vector2(used_width + 4.0, row_top))
		row_top += 10.0


## "if all fail" and one pip per penalty step. The penalties are totals
## (5, 15 or 30 points for 1, 2 or 3 failed quests), so only the pip for the
## number of quests ticked is lit (filled amber, dark number); the others are
## outlines with a grey number.
func _draw_penalty_pips() -> void:
	var pips := _penalty_pips
	var row_height := 10.0
	var row_top: float = floorf((pips.size.y - row_height) / 2.0)
	var pip_texts: Array[String] = []
	var row_width: float = PixelGlyphs.text_width("if all fail") + 4.0 + 1.0 + PixelGlyphs.text_width("pts")
	for penalty_points in QUEST_PENALTY_POINTS:
		pip_texts.append("−%d" % penalty_points)
		row_width += PixelGlyphs.text_width(pip_texts[-1]) + 6.0 + 3.0
	var next_left: float = floorf((pips.size.x - row_width) / 2.0)
	next_left += PixelGlyphs.draw_text(pips, Vector2(next_left, row_top), "if all fail", PixelGlyphs.COLOR_MUTED_TEXT) + 4.0
	for penalty_index in pip_texts.size():
		var penalty_text: String = pip_texts[penalty_index]
		var pip_rect := Rect2(Vector2(next_left, row_top), Vector2(PixelGlyphs.text_width(penalty_text) + 6.0, row_height))
		var is_lit: bool = penalty_index == lit_penalty_pip_index(_chosen_quest_ids.size())
		if is_lit:
			pips.draw_rect(pip_rect, PixelGlyphs.COLOR_AMBER)
			PixelGlyphs.draw_text(pips, pip_rect.position + Vector2(3, 0), penalty_text, PixelGlyphs.COLOR_OUTLINE)
		else:
			pips.draw_rect(pip_rect.grow(-0.5), COLOR_PIP_OFF, false, 1.0)
			PixelGlyphs.draw_text(pips, pip_rect.position + Vector2(3, 0), penalty_text, COLOR_PIP_OFF)
		next_left = pip_rect.end.x + 3.0
	PixelGlyphs.draw_text(pips, Vector2(next_left + 1.0, row_top), "pts", PixelGlyphs.COLOR_MUTED_TEXT)
