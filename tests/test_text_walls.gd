extends RefCounted
## Checks of the "minimize text walls" redesign (design/minimize_text_walls_options.md):
## NumberFormat, the pixel glyphs and text fitting, the warning lamps, the
## score groups of the final screen, the orbit schematic, and the new mission
## and final screens. Everything changed in GameState is put back.


func run_tests(report: TestReport) -> void:
	_check_number_format(report)
	_check_glyphs_and_text_fitting(report)
	_check_warning_lamps(report)
	_check_score_groups(report)
	_check_orbit_schematic(report)
	_check_mission_select(report)
	_check_final_screen(report)
	_check_data_sources_codex(report)
	_check_lamp_focus_and_overflow(report)


func _check_number_format(report: TestReport) -> void:
	report.check(NumberFormat.money(12.5) == "$12.5M", "money keeps one decimal")
	report.check(NumberFormat.money(30.0) == "$30M", "whole money has no decimals")
	report.check(NumberFormat.money(16.55) == "$16.6M", "money rounds to one decimal")
	report.check(NumberFormat.money(-3.0) == "−$3M", "negative money has a minus sign")
	report.check(NumberFormat.money(-0.04) == "$0M", "money that rounds to zero has no minus sign")
	report.check(NumberFormat.money(-0.06) == "−$0.1M", "money that rounds below zero keeps its sign")
	report.check(NumberFormat.duration(16635.0) == "4h37m", "16635 seconds read 4h37m")
	report.check(NumberFormat.duration(725.0) == "12m05s", "under an hour shows minutes and seconds")
	report.check(NumberFormat.duration(45.9) == "45s", "under a minute shows seconds")
	report.check(NumberFormat.duration(INF) == "--", "an endless duration reads --")
	report.check(NumberFormat.points_total(81.6) == "82", "totals are whole points")
	report.check(NumberFormat.points_total(-4.6) == "−5", "a negative total keeps its sign")
	report.check(NumberFormat.points_row(16.25) == "16.3", "rows keep at most one decimal")
	report.check(NumberFormat.points_row(15.0) == "15", "whole rows have no decimals")
	report.check(NumberFormat.points_row(-15.0) == "−15", "a penalty row has a minus sign")
	report.check(NumberFormat.points_row(-0.01) == "0", "a tiny negative row reads 0, not −0")
	report.check(NumberFormat.kilometers(400.0) == "400km", "kilometres are whole")
	report.check(NumberFormat.kilometers(2.5) == "2.5km", "short distances keep one decimal")
	report.check(NumberFormat.meters_per_second(1234.5) == "1235m/s", "speeds are whole")
	report.check(NumberFormat.signed_difference(42.0) == "+42", "a difference shows its sign")
	report.check(NumberFormat.signed_difference(-7.5) == "−7.5", "a small difference keeps one decimal")
	report.check(NumberFormat.compact(5000.0) == "5000", "compact numbers drop .0")


func _check_glyphs_and_text_fitting(report: TestReport) -> void:
	for glyph_name: String in PixelGlyphs.PATTERNS:
		var rows: Array = PixelGlyphs.PATTERNS[glyph_name]
		var is_seven_by_seven: bool = rows.size() == PixelGlyphs.GLYPH_SIZE_PIXELS
		for row: String in rows:
			is_seven_by_seven = is_seven_by_seven and row.length() == PixelGlyphs.GLYPH_SIZE_PIXELS
		report.check(is_seven_by_seven, "glyph %s is 7 x 7 pixels" % glyph_name)
	report.check(PixelGlyphs.PATTERNS["lamp_blocking"] != PixelGlyphs.PATTERNS["lamp_warning"]
			and PixelGlyphs.PATTERNS["lamp_warning"] != PixelGlyphs.PATTERNS["lamp_ok"],
			"the three lamps differ by shape, not only by colour")
	report.check(PixelGlyphs.TEXT_SIZE_PIXELS >= 8, "no text is smaller than 8 pixels")

	var long_text := "This sentence is far too long to fit on two short lines of a card in the mission column at all."
	var lines: Array[String] = PixelGlyphs.wrap_lines(long_text, 120.0, 2)
	report.check(lines.size() == 2, "wrapped text stops at the line limit")
	report.check(lines[1].ends_with(PixelGlyphs.ELLIPSIS), "cut text ends in an ellipsis")
	for line in lines:
		report.check(PixelGlyphs.text_width(line) <= 120.0, "every wrapped line fits its width")
	var short_lines: Array[String] = PixelGlyphs.wrap_lines("Short text.", 120.0, 2)
	report.check(short_lines == ["Short text."], "short text is left alone")
	report.check(PixelGlyphs.fit_to_width("abcdefghijklmnopqrstuvwxyz", 40.0).ends_with(PixelGlyphs.ELLIPSIS), "a long line is cut")
	report.check(PixelGlyphs.without_placeholder_prefix("Placeholder: study the sky.") == "study the sky.", "the placeholder prefix becomes a badge")
	report.check(PixelGlyphs.without_placeholder_prefix("Placeholder mission: fly.") == "fly.", "the mission placeholder prefix becomes a badge")


func _check_warning_lamps(report: TestReport) -> void:
	report.check(WarningLamps.lamps_from_summary(null).is_empty(), "no summary means no lamps")
	var summary := PlanSummary.new()
	var blocking_problems: Array[String] = ["Stage 2 has a liquid engine but no tank."]
	summary.blocking_problems = blocking_problems
	var warnings: Array[String] = [
		"Stage 2 has a liquid engine but no tank.",
		RocketModel.WARNING_PREFIX + " Pulse 1 uses a stage that is already dropped or empty.",
		RocketModel.WARNING_PREFIX + " Pulse 1 uses a stage that is already dropped or empty.",
		RocketModel.WARNING_PREFIX + " Stage 1 fires first at launch with 10.0 kilonewtons, less than the weight it lifts (20.0 kilonewtons).",
	]
	summary.warnings = warnings
	var lamps: Array[Dictionary] = WarningLamps.lamps_from_summary(summary)
	report.check(lamps.size() == 3, "duplicate sentences make one lamp (%d lamps)" % lamps.size())
	report.check(lamps[0]["severity"] == WarningLamps.Severity.BLOCKING and lamps[0]["target_text"] == "S2", "a blocking sentence about stage 2 is a red lamp on S2")
	report.check(lamps[1]["pulse_number"] == 1 and lamps[1]["target_text"] == "P1", "a pulse sentence goes to its pulse")
	report.check(not lamps[1]["sentence"].begins_with(RocketModel.WARNING_PREFIX), "the lamp shape replaces the Warning: prefix")
	report.check(WarningLamps.counts(lamps) == Vector2i(1, 2), "the bezel counts one blocking lamp and two warnings")
	report.check(WarningLamps.worst_severity_for_stage(lamps, 2) == WarningLamps.Severity.BLOCKING, "stage 2 is blocked")
	report.check(WarningLamps.worst_severity_for_stage(lamps, 1) == WarningLamps.Severity.WARNING, "stage 1 has advice")
	report.check(WarningLamps.worst_severity_for_stage(lamps, 3) == WarningLamps.Severity.OK, "stage 3 is fine")
	report.check(WarningLamps.worst_severity_for_pulse(lamps, 1) == WarningLamps.Severity.WARNING, "pulse 1 has advice")
	var rocket_summary := PlanSummary.new()
	var rocket_problems: Array[String] = ["The rocket has no engine."]
	rocket_summary.blocking_problems = rocket_problems
	rocket_summary.warnings = rocket_problems.duplicate()
	report.check(WarningLamps.lamps_from_summary(rocket_summary)[0]["target_text"] == WarningLamps.ROCKET_TARGET_TEXT, "a sentence about no stage is a rocket lamp")
	var planning_console_script: GDScript = load("res://scripts/design/PlanningConsole.gd")
	report.check(planning_console_script.message_line("", WarningLamps.Severity.OK) == "Ready to launch.", "no lamp sentence means ready")
	report.check(planning_console_script.message_line("Stage 2 has no tank.", WarningLamps.Severity.BLOCKING).contains("Cannot launch"), "a blocking sentence says it blocks")


func _check_score_groups(report: TestReport) -> void:
	var score := ScoreReport.new()
	score.lines.append(ScoreLine.create("Mission", "Orbit achieved", 20.0, 20.0, "Orbit reached."))
	score.lines.append(ScoreLine.create("Mission", "Orbit shape", 8.0, 10.0, "Eccentricity off."))
	score.lines.append(ScoreLine.create("Budget", "Within budget", 25.0, 25.0, "Within budget."))
	score.lines.append(ScoreLine.create("Side quests", "Keep a reserve", 0.0, 20.0, "Reserve too low."))
	score.lines.append(ScoreLine.create("Side quests", "Failure penalty", -5.0, 0.0, "One failed quest."))
	var groups: Array[Dictionary] = MissionPresentation.score_groups(score)
	report.check(groups.size() == 4, "the final screen has four score groups")
	report.check(groups[0]["title"] == "MISSION" and groups[3]["title"] == "QUESTS", "groups keep their order")
	report.check_close(groups[0]["earned_points"], 28.0, 0.0001, "mission group sums its points")
	report.check_close(groups[0]["maximum_points"], 30.0, 0.0001, "mission group sums its maxima")
	report.check(groups[0]["tag"] == "ecc. off −2", "the mission tag names the biggest loss (%s)" % groups[0]["tag"])
	report.check(groups[1]["tag"] == "full marks" and not groups[1]["has_loss"], "a full group says so")
	report.check(groups[2]["tag"] == "none taken", "an empty group says none taken")
	report.check(groups[3]["tag"] == "quest failed −20", "a failed quest is tagged in points wording (%s)" % groups[3]["tag"])
	report.check_close(groups[3]["penalty_points"], -5.0, 0.0001, "the penalty is kept apart from the bar")
	report.check(MissionPresentation.group_explanation(groups[0]).contains("Eccentricity off."), "the full sentence stays one click away")
	report.check(MissionPresentation.event_severity({"outcome": "Collision", "did_player_react": false}) == WarningLamps.Severity.BLOCKING, "damage is a red pip")
	report.check(MissionPresentation.event_severity({"outcome": "Avoided", "did_player_react": true}) == WarningLamps.Severity.OK, "a reaction is a green pip")
	report.check(MissionPresentation.event_severity({"outcome": "Passed safely", "did_player_react": false}) == WarningLamps.Severity.OK, "a safe pass is a green pip")
	report.check(MissionPresentation.event_severity({"outcome": "Pending", "did_player_react": false}) == WarningLamps.Severity.WARNING, "an unresolved event is an amber pip")
	report.check(MissionPresentation.event_severity({"outcome": "Observed", "did_player_react": false}) == WarningLamps.Severity.WARNING, "an event only watched is an amber pip")
	report.check(MissionPresentation.event_severity({"outcome": "Collision avoided", "did_player_react": true}) == WarningLamps.Severity.OK, "'Collision avoided' is not damage")
	report.check(MissionPresentation.event_severity({"outcome": "No damage", "did_player_react": false}) == WarningLamps.Severity.OK, "'No damage' is not damage")
	report.check(MissionPresentation.event_severity({"outcome": "White-out", "did_player_react": false}) == WarningLamps.Severity.WARNING, "'white-out' does not match 'hit'")
	report.check(MissionPresentation.event_severity({"outcome": "Threat avoided", "did_player_react": false}) == WarningLamps.Severity.OK, "T07's avoided threat is green")
	report.check(MissionPresentation.event_severity({"outcome": "Engine failed", "did_player_react": false}) == WarningLamps.Severity.BLOCKING, "T07's engine failure is damage")
	report.check(MissionPresentation.event_severity({"outcome": "Sensor failed", "did_player_react": true}) == WarningLamps.Severity.BLOCKING, "damage stays damage after a reaction")


func _check_orbit_schematic(report: TestReport) -> void:
	var mission: Dictionary = GameData.all_missions()[0]
	var schematic := OrbitSchematic.new()
	schematic.size = Vector2(196, 148)
	schematic.show_mission(mission)
	report.check(schematic.altitude_stretch_factor > 1.0, "the mini schematic stretches altitude")
	report.check(schematic.stretch_tag_text().contains("not to scale"), "a stretched diagram says it is not to scale")
	var highest_ring_kilometers := 0.0
	for ring_kilometers in mission["display"]["altitude_ring_kilometers"]:
		highest_ring_kilometers = maxf(highest_ring_kilometers, float(ring_kilometers))
	report.check(schematic.drawn_radius_pixels(highest_ring_kilometers) <= 74.0, "every ring fits the small diagram")
	var target: Dictionary = mission["target"]
	var halo_width_pixels: float = schematic.drawn_radius_pixels(float(target["altitude_kilometers"]) + float(target["altitude_tolerance_kilometers"])) \
			- schematic.drawn_radius_pixels(float(target["altitude_kilometers"]) - float(target["altitude_tolerance_kilometers"]))
	report.check(halo_width_pixels >= OrbitSchematic.MINIMUM_BAND_WIDTH_PIXELS, "the tolerance halo is at least 2 pixels wide")
	var elements := OrbitElements.new()
	var body_radius_meters: float = GameData.body(mission["body_id"])["radius_meters"]
	elements.semi_major_axis_meters = body_radius_meters + 1000.0 * (float(target["altitude_kilometers"]) + 42.0)
	elements.apoapsis_radius_meters = elements.semi_major_axis_meters
	elements.periapsis_radius_meters = elements.semi_major_axis_meters
	schematic.show_result(mission, elements)
	report.check_close(schematic.altitude_miss_kilometers(), 42.0, 0.001, "the result labels the miss in kilometres")
	schematic.show_result(mission, null)
	report.check(is_nan(schematic.altitude_miss_kilometers()), "no orbit means no miss label")
	schematic.free()


func _check_mission_select(report: TestReport) -> void:
	var screen: Control = load("res://scenes/MissionSelect.tscn").instantiate()
	GameState.add_child(screen)
	screen._on_mission_chosen(GameData.all_missions()[0])
	report.check(screen._quest_contents.get_child_count() == GameData.all_missions()[0]["side_quests"].size(), "every quest has a card")
	for card in screen._details_contents.get_children():
		if card is ChoiceCard:
			report.check(card._body_lines.size() <= ChoiceCard.MAXIMUM_BODY_LINE_COUNT, "a science card shows at most two lines")
			report.check(card.fit_star_count >= 0, "a science card shows fit stars")
	report.check(screen._budget_label.text.contains("$30M"), "the footer shows the budget as money")
	report.check(screen.lit_penalty_pip_index(0) == -1, "no quest ticked lights no penalty pip")
	report.check(screen.lit_penalty_pip_index(2) == 1, "two quests light only the -15 total, not -5 and -15")
	report.check(screen.lit_penalty_pip_index(5) == 2, "more than three quests light the -30 total")
	report.check(screen.quest_rule_text({"type": "reserve_delta_v_at_most", "delta_v_meters_per_second": 10}) == "end reserve ≤10m/s",
			"the quest rule is a chip, never cut from the card")
	for card in screen._quest_contents.get_children():
		if card is ChoiceCard:
			report.check(not card.tooltip_text.is_empty(), "a quest card shows its full text on hover")
			var tooltip: Label = card._make_custom_tooltip(card.tooltip_text)
			var tooltip_width: float = maxf(PixelTooltip.MAXIMUM_WIDTH_PIXELS, card._card_width_pixels)
			var widest_line := 0.0
			for line in tooltip.text.split("\n"):
				widest_line = maxf(widest_line, PixelGlyphs.text_width(line))
			report.check(widest_line <= tooltip_width,
					"a quest card's hover text wraps inside its box (widest line %.0f of %.0f px)" % [widest_line, tooltip_width])
			report.check(tooltip.text.replace("\n", " ").replace("  ", " ") == card.tooltip_text.replace("\n", " "),
					"a quest card's hover text is wrapped, never cut")
			tooltip.free()
	report.check(PixelTooltip.make("  ") == null, "empty hover text shows no tooltip")
	var tooltip_panel: StyleBoxFlat = screen.get_theme_stylebox("panel", "TooltipPanel") as StyleBoxFlat
	report.check(tooltip_panel != null and is_equal_approx(tooltip_panel.bg_color.a, 1.0),
			"the tooltip panel is opaque, so the screen behind never shows through")
	screen._on_quest_toggled(true, "keep_reserve_placeholder")
	report.check(screen._budget_label.text.contains("$35M"), "the footer adds the grant live (%s)" % screen._budget_label.text)
	var widest_budget: String = screen.budget_text({"id": "rich"}, 100.0, 15.0)
	var budget_font: Font = screen._budget_label.get_theme_font("font")
	report.check(budget_font.get_string_size(widest_budget, HORIZONTAL_ALIGNMENT_LEFT, -1, 12).x <= screen.BUDGET_SCREEN.size.x,
			"a $100M budget with grants fits the budget line (%s)" % widest_budget)
	var long_card := ChoiceCard.new()
	long_card.setup("A quest title that is far too long for one line", "", [], ScreenLayout.MISSION_SELECT_QUEST_CARD_BOX.size.x)
	report.check(long_card._title_lines.size() == 2, "a long card title wraps to two lines")
	long_card.free()
	for panel_screen: Rect2 in ScreenLayout.MISSION_SELECT_PANEL_SCREENS:
		report.check(Rect2(Vector2.ZERO, ScreenLayout.SCREEN_SIZE).encloses(panel_screen), "the three columns fit the 640 pixel canvas")
	var background: TextureRect = screen.get_node_or_null("MissionChoiceBackground")
	report.check(background != null and background.texture != null
			and background.texture.resource_path == ScreenLayout.MISSION_SELECT_BACKGROUND_PATH,
			"mission select draws the mission_choice mock-up as its background")
	report.check(background != null and background.texture != null
			and background.texture.get_size() * ScreenLayout.MOCKUP_SCALE == ScreenLayout.SCREEN_SIZE,
			"the mission_choice mock-up is 128 x 80, five times smaller than the screen")
	report.check(background != null and background.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST,
			"the mission_choice mock-up keeps hard pixels")
	var first_science_card: ChoiceCard = null
	for card in screen._details_contents.get_children():
		if card is ChoiceCard:
			first_science_card = card
			break
	report.check(first_science_card != null
			and first_science_card.custom_minimum_size.x == ScreenLayout.MISSION_SELECT_SCIENCE_CARD_BOX.size.x
			and first_science_card.custom_minimum_size.y >= ScreenLayout.MISSION_SELECT_SCIENCE_CARD_BOX.size.y,
			"the first science card covers the mock-up's science box")
	screen.free()


func _check_final_screen(report: TestReport) -> void:
	var saved_score: ScoreReport = GameState.score
	var saved_result: FlightResult = GameState.flight_result
	var saved_mission: Dictionary = GameState.mission
	GameState.mission = GameData.all_missions()[0]
	var result := FlightResult.new()
	result.flight_duration_seconds = 16635.0
	result.event_log.append({"event_type_id": "satellite_conjunction", "time_seconds": 600.0, "did_player_react": true,
			"delta_v_spent_meters_per_second": 2.5, "outcome": "Avoided", "explanation": "Test explanation sentence."})
	var score := ScoreReport.new()
	score.lines.append(ScoreLine.create("Mission", "Orbit shape", 8.0, 10.0, "Eccentricity sentence."))
	score.total_points = 81.6
	score.band_name = "Success"
	GameState.flight_result = result
	GameState.score = score
	var screen: Control = load("res://scenes/FinalScreen.tscn").instantiate()
	GameState.add_child(screen)
	report.check(screen.score_groups.size() == 4, "the final screen draws one bar per group")
	report.check(screen.score_groups[0]["title"] == "ORBIT", "the Mission group is the mock-up's ORBIT row")
	report.check(screen._group_index_at(screen._row_rect(2).get_center()) == 2, "a click on a mock-up row picks that group")
	report.check(not screen._flight_log.visible and screen._bars.visible, "the score page shows first")
	screen.show_flight_log(true)
	report.check(screen._flight_log.visible and not screen._bars.visible, "the Flight log button shows the orbit and the events")
	screen.show_flight_log(false)
	screen.select_group(0)
	report.check(screen._detail_label.text.contains("Eccentricity sentence."), "clicking a bar shows its full sentence")
	screen.select_event(0)
	report.check(screen._detail_label.text.contains("Test explanation sentence."), "clicking a pip shows the event explanation")
	report.check(screen._detail_label.text.contains("10m00s"), "event times use NumberFormat")
	# Keyboard: the bars and the pips take the focus and answer the arrow keys.
	report.check(screen._bars.focus_mode == Control.FOCUS_ALL and screen._timeline.focus_mode == Control.FOCUS_ALL, "bars and pips can take the keyboard focus")
	screen.focus_group(0)
	screen._on_bars_input(_key_event(KEY_DOWN))
	report.check(screen._focused_group_index == 1, "Down moves the focus to the next bar")
	screen._on_bars_input(_key_event(KEY_ENTER))
	report.check(screen._detail_label.text.contains("BUDGET"), "Enter opens the focused bar's sentence")
	screen._on_bars_input(_key_event(KEY_UP))
	screen._on_bars_input(_key_event(KEY_UP))
	report.check(screen._focused_group_index == 0, "Up stops at the first bar")
	screen.focus_event(0)
	screen._on_timeline_input(_key_event(KEY_RIGHT))
	report.check(screen._focused_event_index == 0, "Right stops at the last pip")
	screen.select_group(-1)
	screen._on_timeline_input(_key_event(KEY_ENTER))
	report.check(screen._detail_label.text.contains("Test explanation sentence."), "Enter opens the focused pip's event")
	screen.free()
	GameState.score = saved_score
	GameState.flight_result = saved_result
	GameState.mission = saved_mission


func _check_data_sources_codex(report: TestReport) -> void:
	var codex := DataSourcesCodex.new()
	GameState.add_child(codex)
	var has_every_part := true
	for category in [GameData.CATEGORY_ENGINE, GameData.CATEGORY_TANK, GameData.CATEGORY_TELEMETRY, GameData.CATEGORY_SCIENCE]:
		for part: Dictionary in GameData.parts_in_category(category):
			has_every_part = has_every_part and codex.has_entry(part["id"])
	report.check(has_every_part, "the codex lists every part's source")
	codex.open_at("engine_solid_kick")
	report.check(codex.visible, "the codex opens at a part")
	codex.free()


func _key_event(keycode: Key) -> InputEventKey:
	var key_event := InputEventKey.new()
	key_event.keycode = keycode
	key_event.physical_keycode = keycode
	key_event.pressed = true
	return key_event


func _check_lamp_focus_and_overflow(report: TestReport) -> void:
	var many_lamps: Array[Dictionary] = []
	for stage_number in range(1, 13):
		many_lamps.append({"severity": WarningLamps.Severity.WARNING, "sentence": "Stage %d advice." % stage_number,
				"stage_number": stage_number, "pulse_number": 0, "target_text": "S%d" % stage_number})
	var lamp_bar := LampBar.new()
	lamp_bar.size = Vector2(160, 13)
	lamp_bar.set_lamps(many_lamps)
	var entries: Array[Dictionary] = lamp_bar.entries()
	report.check(entries.size() < many_lamps.size() and entries.back().get("is_overflow", false), "lamps past the edge become one +N chip")
	var hidden_count: int = many_lamps.size() - (entries.size() - 1)
	report.check(entries.back()["target_text"] == "+%d" % hidden_count, "the overflow chip counts the hidden lamps")
	report.check(entries.back()["sentence"].contains("Stage 12 advice."), "the overflow chip holds the hidden sentences")
	report.check(lamp_bar._chip_index_at(Vector2(158, 6)) == -1 or lamp_bar._chip_index_at(Vector2(158, 6)) == entries.size() - 1, "nothing past the visible chips can be clicked")
	report.check(lamp_bar.step_focus(-1) and lamp_bar.active_lamp_index() == entries.size() - 1, "Shift+Tab from no focus wraps to the last chip")
	lamp_bar.set_lamps(many_lamps)
	report.check(lamp_bar.active_lamp_index() == entries.size() - 1, "a refresh keeps the focused chip")
	lamp_bar.free()

	var planning_console_script: GDScript = load("res://scripts/design/PlanningConsole.gd")
	report.check(planning_console_script.message_line("Stage 1 advice.", WarningLamps.Severity.WARNING, 2).contains("(+2 more)"), "the message says how many more lamps are lit")

	var design := RocketDesign.new()
	design.add_stage("engine_liquid_small", "tank_aluminium_blowdown")
	var upper_stage: Stage = design.add_stage("engine_liquid_small")
	var preview := RocketStackPreview.new()
	preview.is_interactive = true
	preview.size = ScreenLayout.ROCKET_DESIGN_PREVIEW_SCREEN.size
	preview.show_design(design, upper_stage.stage_id)
	preview.show_lamps(many_lamps)
	report.check(preview.next_tank_text() == "next tank → S2", "the selected stage is named as the next tank's stage")
	report.check(preview.step_lamp_focus(-1) and preview.focused_lamp_index() == preview.lamp_spots().size() - 1, "Shift+Tab into the stack starts at the last lamp")
	var focused_index: int = preview.focused_lamp_index()
	preview.show_design(design, upper_stage.stage_id)
	preview.show_lamps(many_lamps)
	report.check(preview.focused_lamp_index() == focused_index, "a refresh keeps the focused lamp")
	preview.free()
