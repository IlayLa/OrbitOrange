extends Control
## Displays the scored result and flight log; also works without an active run.
##
## Laid out without text walls (design/minimize_text_walls_options.md,
## Options 2 and 3):
##   header     portrait, band name, the whole-number total, end reason, time
##   bars       one earned/lost bar per scoring group with a 2-3 word tag;
##              clicking a bar writes its full sentences in the detail box
##   orbit      the achieved orbit (solid white) over the target (dashed
##              green), with the miss labelled ("+42km")
##   timeline   one pip per flight event; hovering a pip names it, clicking
##              writes its explanation in the detail box
## The explanations of Scoring stay available, one click away.

const PORTRAIT_FOLDER := "res://assets/art/portraits/"
## Amit's pose per band; a band with two poses picks one by a coin toss.
const PORTRAIT_NAMES := {
	"Failure": ["amit_concerned", "amit_judging"],
	"Partial Success": ["amit_explaining"],
	"Success": ["amit_happy"],
	"Great Success": ["amit_greatsuccess"],
	"Perfect": ["amit_greatsuccess"],
	"Scientific Breakthrough": ["amit_greatsuccess"],
}
## Amit fills only the middle of each 128x80 sprite; this 70x70 window holds
## every pose (widest is amit_explaining) and is drawn 1:1 in the portrait rect.
const PORTRAIT_CROP := Rect2(19, 1, 70, 70)
const PERFECT_SPEECH_TEXT := "I Like It - Perfect"
const SPEECH_BUBBLE_TEXTS := {
	"Great Success": "Great Success!!",
	"Perfect": PERFECT_SPEECH_TEXT,
	"Scientific Breakthrough": "I Like It - Breakthrough",
}
const FIREWORK_BANDS := ["Scientific Breakthrough"]
## The fireworks stay in this rectangle around the portrait: left of the
## header (which starts at x 92) and inside the screen.
const FIREWORK_RECT := Rect2(0, 0, 88, 84)
## Burst centres around the portrait, in screen pixels. Each is at least
## FIREWORK_LARGEST_RADIUS_PIXELS + 2 inside FIREWORK_RECT, so no burst is cut.
const FIREWORK_CENTERS := [Vector2(15, 16), Vector2(72, 15), Vector2(14, 62), Vector2(44, 15), Vector2(73, 58)]
const FIREWORK_LARGEST_RADIUS_PIXELS := 12.0
const FIREWORK_COLORS := [Color("ff5000"), Color("ffd27a"), Color("6ee06e"), Color("ffffff"), Color("7ac8ff")]
const FIREWORK_FRAME_SECONDS := 0.08
const FIREWORK_FRAMES_PER_BURST := 14
const BARS_PANEL_RECT := Rect2(10, 84, 372, 176)
const ORBIT_PANEL_RECT := Rect2(390, 84, 240, 176)
const TIMELINE_PANEL_RECT := Rect2(10, 264, 620, 60)
const DETAIL_RECT := Rect2(10, 328, 410, 68)
const BAR_ROW_TOP_PIXELS := 20.0
const BAR_ROW_HEIGHT_PIXELS := 38.0
const BAR_LEFT_PIXELS := 8.0
const BAR_WIDTH_PIXELS := 250.0
const BAR_HEIGHT_PIXELS := 9.0
const PIP_HIT_DISTANCE_PIXELS := 5.0
const COLOR_EARNED := Color("ff5000")
const COLOR_LOST := Color("2a3240")
const COLOR_LOST_DITHER := Color("4a5568")
const COLOR_HEADER := Color("ffd27a")
## Dark plate under the header text, which does not read on the tan bezel.
const COLOR_HEADER_PLATE := Color("10141c")
const HEADER_PLATE_MARGIN_PIXELS := 3.0
## The speech bubble's tail: its base on the bubble's lower edge, and its tip
## down and to the left of the base, towards Amit, below the band name.
const BUBBLE_TAIL_BASE_WIDTH_PIXELS := 8.0
const BUBBLE_TAIL_TIP_OFFSET := Vector2(-9, 12)
const DETAIL_HINT := "Click a bar or an event pip to read why."

## The groups of GameState.score, from MissionPresentation.score_groups.
var score_groups: Array[Dictionary] = []
var _score: ScoreReport
var _result: FlightResult
var _header: Control
var _bars: Control
var _timeline: Control
var _schematic: OrbitSchematic
var _orbit_legend: Control
var _detail_label: RichTextLabel
var _hovered_group_index: int = -1
var _selected_group_index: int = -1
var _hovered_event_index: int = -1
## The bar row and the pip that have the keyboard focus; -1 for none.
var _focused_group_index: int = -1
var _focused_event_index: int = -1
var _selected_event_index: int = -1


func _ready() -> void:
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	theme = MissionPresentation.create_theme()
	MissionPresentation.add_background(self)
	_score = GameState.score
	_result = GameState.flight_result
	score_groups = MissionPresentation.score_groups(_score)

	var portrait := TextureRect.new()
	portrait.position = Vector2(12, 8)
	portrait.size = Vector2(70, 70)
	portrait.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	portrait.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	var band_name := _score.band_name if _score != null else "Failure"
	if band_name in FIREWORK_BANDS:
		_add_fireworks()
	portrait.texture = portrait_texture(band_name)
	add_child(portrait)

	_header = Control.new()
	_header.position = Vector2(92, 6)
	_header.size = Vector2(538, 74)
	_header.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header.draw.connect(_draw_header)
	add_child(_header)
	var bubble_text: String = SPEECH_BUBBLE_TEXTS.get(band_name, "")
	if bubble_text != "":
		_add_speech_bubble(bubble_text)

	_bars = _add_panel(BARS_PANEL_RECT)
	_bars.mouse_filter = Control.MOUSE_FILTER_STOP
	_bars.draw.connect(_draw_bars)
	_bars.gui_input.connect(_on_bars_input)
	_bars.mouse_exited.connect(_on_bars_mouse_exited)
	# Keyboard: Tab reaches the bars, Up and Down move, Enter opens the sentence.
	_bars.focus_mode = Control.FOCUS_ALL
	_bars.focus_entered.connect(func() -> void: focus_group(maxi(0, _focused_group_index)))
	_bars.focus_exited.connect(_bars.queue_redraw)

	var orbit_panel: Control = _add_panel(ORBIT_PANEL_RECT)
	orbit_panel.draw.connect(func() -> void:
		PixelGlyphs.draw_text(orbit_panel, Vector2(8, 4), "ORBIT", COLOR_HEADER, PixelGlyphs.TITLE_SIZE_PIXELS))
	_schematic = OrbitSchematic.new()
	_schematic.position = Vector2(6, 18)
	_schematic.size = Vector2(ORBIT_PANEL_RECT.size.x - 12, ORBIT_PANEL_RECT.size.y - 38)
	_schematic.clip_contents = true
	_schematic.mouse_filter = Control.MOUSE_FILTER_IGNORE
	orbit_panel.add_child(_schematic)
	if not GameState.mission.is_empty():
		var achieved_elements: OrbitElements = _result.final_elements if _result != null else null
		_schematic.show_result(GameState.mission, achieved_elements, GameState.science_mission())
	_orbit_legend = Control.new()
	_orbit_legend.position = Vector2(6, ORBIT_PANEL_RECT.size.y - 18)
	_orbit_legend.size = Vector2(ORBIT_PANEL_RECT.size.x - 12, 14)
	_orbit_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_orbit_legend.draw.connect(_draw_orbit_legend)
	orbit_panel.add_child(_orbit_legend)

	_timeline = _add_panel(TIMELINE_PANEL_RECT)
	_timeline.mouse_filter = Control.MOUSE_FILTER_STOP
	_timeline.draw.connect(_draw_timeline)
	_timeline.gui_input.connect(_on_timeline_input)
	_timeline.mouse_exited.connect(hover_event.bind(-1))
	# Keyboard: Left and Right move from pip to pip, Enter opens the event.
	_timeline.focus_mode = Control.FOCUS_ALL
	_timeline.focus_entered.connect(func() -> void: focus_event(maxi(0, _focused_event_index)))
	_timeline.focus_exited.connect(func() -> void: hover_event(-1))

	_detail_label = RichTextLabel.new()
	_detail_label.bbcode_enabled = true
	_detail_label.position = DETAIL_RECT.position
	_detail_label.size = DETAIL_RECT.size
	_detail_label.scroll_active = true
	_detail_label.add_theme_font_size_override("normal_font_size", 8)
	_detail_label.add_theme_font_size_override("bold_font_size", 8)
	_detail_label.add_theme_constant_override("line_separation", -1)
	var detail_style := StyleBoxFlat.new()
	detail_style.bg_color = Color(ScreenLayout.COLOR_SPACE_BLACK, 0.7)
	detail_style.set_content_margin_all(3)
	_detail_label.add_theme_stylebox_override("normal", detail_style)
	add_child(_detail_label)
	_show_detail("")

	var menu_button := Button.new()
	menu_button.text = "Back to main menu"
	menu_button.position = Vector2(426, 356)
	menu_button.size = Vector2(204, 40)
	menu_button.pressed.connect(GameState.go_to_scene.bind(GameState.MAIN_MENU_SCENE_PATH))
	add_child(menu_button)


## Writes the full sentences of one score group (by index in score_groups)
## in the detail box, as a click on its bar does.
func select_group(group_index: int) -> void:
	_selected_group_index = group_index
	_selected_event_index = -1
	if group_index < 0 or group_index >= score_groups.size():
		_show_detail("")
	else:
		var group: Dictionary = score_groups[group_index]
		_show_detail("[b]%s[/b]  %s" % [group["title"], MissionPresentation.group_explanation(group).replace("[", "[lb]")])
	_bars.queue_redraw()
	_timeline.queue_redraw()


## Writes the explanation of one flight event in the detail box, as a click
## on its pip does.
func select_event(event_index: int) -> void:
	_selected_event_index = event_index
	_selected_group_index = -1
	if _result == null or event_index < 0 or event_index >= _result.event_log.size():
		_show_detail("")
	else:
		var event: Dictionary = _result.event_log[event_index]
		_show_detail("[b]%s[/b]  %s · reaction: %s, %s spent\n%s" % [_event_title(event).replace("[", "[lb]"),
				str(event.get("outcome", "Unrecorded")).replace("[", "[lb]"),
				"yes" if event.get("did_player_react", false) else "none",
				NumberFormat.meters_per_second(float(event.get("delta_v_spent_meters_per_second", 0.0))),
				str(event.get("explanation", "No explanation supplied.")).replace("[", "[lb]")])
	_bars.queue_redraw()
	_timeline.queue_redraw()


## Moves the keyboard focus to one bar row (clamped to the rows).
func focus_group(group_index: int) -> void:
	if score_groups.is_empty() or _score == null or _score.is_launch_failure:
		_focused_group_index = -1
	else:
		_focused_group_index = clampi(group_index, 0, score_groups.size() - 1)
	_bars.queue_redraw()


## Moves the keyboard focus to one pip (clamped) and shows its name.
func focus_event(event_index: int) -> void:
	var event_count: int = _result.event_log.size() if _result != null else 0
	_focused_event_index = clampi(event_index, 0, event_count - 1) if event_count > 0 else -1
	hover_event(_focused_event_index)


## Shows the name of one event above its pip, as hovering it does. -1 hides it.
func hover_event(event_index: int) -> void:
	_hovered_event_index = event_index
	_timeline.queue_redraw()


func _show_detail(bbcode_text: String) -> void:
	if bbcode_text.is_empty():
		var muted_code: String = PixelGlyphs.COLOR_MUTED_TEXT.to_html(false)
		_detail_label.text = "[color=#%s]%s[/color]" % [muted_code, DETAIL_HINT]
	else:
		_detail_label.text = bbcode_text


func _add_panel(rectangle: Rect2) -> Panel:
	var panel := Panel.new()
	panel.position = rectangle.position
	panel.size = rectangle.size
	var style := StyleBoxFlat.new()
	style.bg_color = ScreenLayout.COLOR_SPACE_BLACK
	style.border_color = ScreenLayout.COLOR_MONITOR_FRAME
	style.set_border_width_all(2)
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)
	return panel


## Returns the pose name for the band; coin (0 or 1) picks between two poses.
static func portrait_name(band_name: String, coin: int = randi() % 2) -> String:
	var names: Array = PORTRAIT_NAMES.get(band_name, PORTRAIT_NAMES["Failure"])
	return names[clampi(coin, 0, names.size() - 1)]


## Returns Amit's portrait for the band, cropped to the part of the sprite he fills.
static func portrait_texture(band_name: String, coin: int = randi() % 2) -> AtlasTexture:
	var texture := AtlasTexture.new()
	texture.atlas = load(PORTRAIT_FOLDER + portrait_name(band_name, coin) + ".png")
	texture.region = PORTRAIT_CROP
	return texture


## Adds looping pixel fireworks behind and around Amit's portrait.
func _add_fireworks() -> void:
	var fireworks := Control.new()
	fireworks.name = "Fireworks"
	fireworks.position = FIREWORK_RECT.position
	fireworks.size = FIREWORK_RECT.size
	fireworks.clip_contents = true
	fireworks.mouse_filter = Control.MOUSE_FILTER_IGNORE
	fireworks.set_meta("frame", 0)
	fireworks.draw.connect(_draw_fireworks.bind(fireworks))
	add_child(fireworks)
	var timer := Timer.new()
	timer.wait_time = FIREWORK_FRAME_SECONDS
	timer.autostart = true
	timer.timeout.connect(func() -> void:
		fireworks.set_meta("frame", int(fireworks.get_meta("frame")) + 1)
		fireworks.queue_redraw())
	fireworks.add_child(timer)


## Each burst grows eight rays of 2x2 pixels and fades, staggered per centre.
func _draw_fireworks(fireworks: Control) -> void:
	var frame: int = fireworks.get_meta("frame")
	for index in FIREWORK_CENTERS.size():
		var burst_frame: int = (frame + index * 5) % (FIREWORK_FRAMES_PER_BURST + 4)
		if burst_frame >= FIREWORK_FRAMES_PER_BURST:
			continue
		var progress := float(burst_frame) / FIREWORK_FRAMES_PER_BURST
		var color: Color = FIREWORK_COLORS[(index + frame / (FIREWORK_FRAMES_PER_BURST + 4)) % FIREWORK_COLORS.size()]
		color.a = 1.0 - progress * progress
		var center: Vector2 = FIREWORK_CENTERS[index]
		var radius := 2.0 + progress * (FIREWORK_LARGEST_RADIUS_PIXELS - 2.0)
		for ray in 8:
			var direction := Vector2.RIGHT.rotated(ray * TAU / 8.0)
			for trail in 2:
				var point := (center + direction * (radius - trail * 3.0)).round()
				fireworks.draw_rect(Rect2(point, Vector2(2, 2)), Color(color, color.a * (1.0 - trail * 0.5)))
		if burst_frame < 3:
			fireworks.draw_rect(Rect2(center.round() - Vector2(1, 1), Vector2(3, 3)), ScreenLayout.COLOR_TEXT_LIGHT)


## Adds Amit's speech bubble beside the band name, its tail pointing back at him.
func _add_speech_bubble(text: String) -> void:
	var bubble := PanelContainer.new()
	bubble.name = "SpeechBubble"
	# Beside the band name drawn by _draw_header (header at x 92, band name at 16 px).
	var band_text: String = _score.band_name.to_upper() if _score != null else ""
	bubble.position = Vector2(92 + PixelGlyphs.text_width(band_text, 16) + 10, 4)
	bubble.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = ScreenLayout.COLOR_TEXT_LIGHT
	style.border_color = COLOR_EARNED
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	style.content_margin_left = 8
	style.content_margin_right = 8
	style.content_margin_top = 3
	style.content_margin_bottom = 3
	bubble.add_theme_stylebox_override("panel", style)
	add_child(bubble)
	var label := Label.new()
	label.name = "SpeechBubbleLabel"
	label.text = text
	label.add_theme_font_size_override("font_size", 12)
	label.add_theme_color_override("font_color", ScreenLayout.COLOR_SPACE_BLACK)
	bubble.add_child(label)
	var tail := Control.new()
	tail.name = "SpeechBubbleTail"
	tail.size = ScreenLayout.SCREEN_SIZE
	tail.mouse_filter = Control.MOUSE_FILTER_IGNORE
	tail.draw.connect(_draw_bubble_tail.bind(tail, bubble))
	bubble.resized.connect(tail.queue_redraw)
	add_child(tail)


## The bubble's tail: a white wedge from the bubble's lower-left corner
## towards Amit, outlined like the bubble. Drawn over the bubble's border so
## the wedge opens into the bubble.
func _draw_bubble_tail(tail: Control, bubble: Control) -> void:
	var base_left := Vector2(bubble.position.x + 6.0, bubble.position.y + bubble.size.y - 2.0)
	var base_right := base_left + Vector2(BUBBLE_TAIL_BASE_WIDTH_PIXELS, 0.0)
	var tip: Vector2 = (base_left + BUBBLE_TAIL_TIP_OFFSET).round()
	tail.draw_colored_polygon(PackedVector2Array([base_left, base_right, tip]), ScreenLayout.COLOR_TEXT_LIGHT)
	tail.draw_line(base_left, tip, COLOR_EARNED, 2.0)
	tail.draw_line(base_right, tip, COLOR_EARNED, 2.0)


func _draw_header() -> void:
	if _score == null:
		_draw_header_plate(Rect2(0, 4, PixelGlyphs.text_width("MISSION REPORT", 16), 16))
		PixelGlyphs.draw_text(_header, Vector2(0, 4), "MISSION REPORT", COLOR_HEADER, 16)
		_draw_header_plate(Rect2(0, 28, PixelGlyphs.text_width("No flight has been scored yet.", 10), 12))
		PixelGlyphs.draw_text(_header, Vector2(0, 28), "No flight has been scored yet.", ScreenLayout.COLOR_TEXT_LIGHT, 10)
		return
	var band_text: String = _score.band_name.to_upper()
	_draw_header_plate(Rect2(0, 2, PixelGlyphs.text_width(band_text, 16), 16))
	PixelGlyphs.draw_text(_header, Vector2(0, 2), band_text, COLOR_HEADER, 16)
	var total_text: String = "0" if _score.is_launch_failure else NumberFormat.points_total(_score.total_points)
	var total_width: float = PixelGlyphs.text_width(total_text, 24)
	_draw_header_plate(Rect2(0, 24, total_width + 4 + PixelGlyphs.text_width("pts", 10), 22))
	PixelGlyphs.draw_text(_header, Vector2(0, 22), total_text, ScreenLayout.COLOR_TEXT_LIGHT, 24)
	PixelGlyphs.draw_text(_header, Vector2(total_width + 4, 34), "pts", PixelGlyphs.COLOR_MUTED_TEXT, 10)

	var chip_left := 0.0
	var chip_top := 60.0
	var reason_severity: int = WarningLamps.Severity.OK
	var reason_text := "no flight data"
	# Without flight data there is nothing to judge: a grey dot, not a green one.
	var reason_color: Color = PixelGlyphs.COLOR_MUTED_TEXT
	if _score.is_launch_failure:
		reason_severity = WarningLamps.Severity.BLOCKING
		reason_text = "launch failed"
	elif _result != null:
		reason_text = str(FlightResult.EndReason.keys()[_result.end_reason]).replace("_", " ").to_lower()
		match _result.end_reason:
			FlightResult.EndReason.MISSION_COMPLETED:
				reason_severity = WarningLamps.Severity.OK
			FlightResult.EndReason.ABORTED:
				reason_severity = WarningLamps.Severity.WARNING
			_:
				reason_severity = WarningLamps.Severity.BLOCKING
	if _score.is_launch_failure or _result != null:
		reason_color = PixelGlyphs.lamp_color(reason_severity)
	var chips: Array[Array] = [[PixelGlyphs.lamp_glyph_name(reason_severity), reason_text, reason_color]]
	if _result != null:
		chips.append(["clock", NumberFormat.duration(_result.flight_duration_seconds), ScreenLayout.COLOR_MONITOR_GRID_LINE])
		chips.append(["fuel", "%s reserve" % NumberFormat.meters_per_second(_result.reserve_delta_v_meters_per_second),
				ScreenLayout.COLOR_MONITOR_GRID_LINE])
	var chips_width := 0.0
	for chip in chips:
		chips_width += PixelGlyphs.chip_width(chip[0], chip[1]) + 10.0
	_draw_header_plate(Rect2(0, chip_top, chips_width - 10.0, PixelGlyphs.LINE_HEIGHT_PIXELS))
	for chip in chips:
		chip_left += PixelGlyphs.draw_chip(_header, Vector2(chip_left, chip_top), chip[0], chip[1], chip[2]) + 10.0


## A dark plate under one row of header text (text_rect in header pixels).
func _draw_header_plate(text_rect: Rect2) -> void:
	_header.draw_rect(text_rect.grow(HEADER_PLATE_MARGIN_PIXELS), COLOR_HEADER_PLATE)


func _draw_bars() -> void:
	PixelGlyphs.draw_text(_bars, Vector2(8, 4), "SCORE", COLOR_HEADER, PixelGlyphs.TITLE_SIZE_PIXELS)
	if _score == null:
		PixelGlyphs.draw_text(_bars, Vector2(8, BAR_ROW_TOP_PIXELS), "Complete a flight to see its score.", PixelGlyphs.COLOR_MUTED_TEXT)
		return
	if _score.is_launch_failure:
		PixelGlyphs.draw_chip(_bars, Vector2(8, BAR_ROW_TOP_PIXELS), "lamp_blocking", "launch failed: every group scores 0",
				ScreenLayout.COLOR_WARNING_RED)
		return
	PixelGlyphs.draw_text(_bars, Vector2(BAR_LEFT_PIXELS + 120, 6), "earned", PixelGlyphs.COLOR_MUTED_TEXT)
	_bars.draw_rect(Rect2(BAR_LEFT_PIXELS + 112, 8, 6, 6), COLOR_EARNED)
	_draw_dither(Rect2(BAR_LEFT_PIXELS + 156, 8, 6, 6))
	PixelGlyphs.draw_text(_bars, Vector2(BAR_LEFT_PIXELS + 164, 6), "lost", PixelGlyphs.COLOR_MUTED_TEXT)
	for group_index in score_groups.size():
		_draw_bar_row(group_index)


func _draw_bar_row(group_index: int) -> void:
	var group: Dictionary = score_groups[group_index]
	var row_top: float = BAR_ROW_TOP_PIXELS + group_index * BAR_ROW_HEIGHT_PIXELS
	var row_rect := Rect2(4, row_top - 2, BARS_PANEL_RECT.size.x - 8, BAR_ROW_HEIGHT_PIXELS - 4)
	if group_index == _selected_group_index:
		_bars.draw_rect(row_rect, ScreenLayout.COLOR_ACCENT_ORANGE, false, 1.0)
	elif group_index == _hovered_group_index:
		_bars.draw_rect(row_rect, ScreenLayout.COLOR_MONITOR_GRID_LINE, false, 1.0)
	if group_index == _focused_group_index and _bars.has_focus():
		# Keyboard focus: a second, light frame with a marker at the left.
		_bars.draw_rect(row_rect.grow(1.0), ScreenLayout.COLOR_MONITOR_GRID_LINE, false, 1.0)
		_bars.draw_rect(Rect2(row_rect.position.x - 1, row_rect.position.y + 2, 3, row_rect.size.y - 4), ScreenLayout.COLOR_MONITOR_GRID_LINE)

	PixelGlyphs.draw_text(_bars, Vector2(BAR_LEFT_PIXELS, row_top), group["title"], ScreenLayout.COLOR_TEXT_LIGHT, PixelGlyphs.TITLE_SIZE_PIXELS)
	var tag_text: String = group["tag"]
	var tag_glyph := "check"
	var tag_color: Color = PixelGlyphs.COLOR_GOOD_GREEN
	if group["has_loss"]:
		tag_glyph = "arrow_down"
		tag_color = PixelGlyphs.COLOR_AMBER
	elif group["lines"].is_empty():
		tag_glyph = ""
		tag_color = PixelGlyphs.COLOR_MUTED_TEXT
	var tag_width: float = PixelGlyphs.chip_width(tag_glyph, tag_text)
	PixelGlyphs.draw_chip(_bars, Vector2(row_rect.end.x - tag_width - 4, row_top + 1), tag_glyph, tag_text, tag_color, tag_color)

	var maximum_points: float = group["maximum_points"]
	var earned_points: float = group["earned_points"]
	var penalty_points: float = group["penalty_points"]
	var bar_top: float = row_top + 14.0
	var bar_rect := Rect2(BAR_LEFT_PIXELS, bar_top, BAR_WIDTH_PIXELS, BAR_HEIGHT_PIXELS)
	if maximum_points > 0.0:
		var earned_width: float = roundf(BAR_WIDTH_PIXELS * clampf(earned_points / maximum_points, 0.0, 1.0))
		_draw_dither(bar_rect)
		_bars.draw_rect(Rect2(bar_rect.position, Vector2(earned_width, BAR_HEIGHT_PIXELS)), COLOR_EARNED)
	_bars.draw_rect(bar_rect.grow(1.0), ScreenLayout.COLOR_MONITOR_FRAME, false, 1.0)
	var points_text := "%s/%s" % [NumberFormat.points_row(earned_points), NumberFormat.points_row(maximum_points)]
	var points_left: float = bar_rect.end.x + 6.0
	points_left += PixelGlyphs.draw_text(_bars, Vector2(points_left, bar_top), points_text, ScreenLayout.COLOR_TEXT_LIGHT) + 4.0
	if penalty_points < 0.0:
		PixelGlyphs.draw_chip(_bars, Vector2(points_left, bar_top), "lamp_blocking", "penalty %s" % NumberFormat.points_row(penalty_points),
				ScreenLayout.COLOR_WARNING_RED, ScreenLayout.COLOR_WARNING_RED)


## The lost part of a bar: a 2 x 2 checker, so lost and earned differ by
## pattern as well as by colour.
func _draw_dither(rectangle: Rect2) -> void:
	_bars.draw_rect(rectangle, COLOR_LOST)
	for cell_y in range(0, int(rectangle.size.y), 2):
		for cell_x in range(0, int(rectangle.size.x), 2):
			if posmod(cell_x + cell_y, 4) == 0:
				_bars.draw_rect(Rect2(rectangle.position + Vector2(cell_x, cell_y), Vector2(1, 1)), COLOR_LOST_DITHER)


func _draw_orbit_legend() -> void:
	var next_left := 0.0
	for dash_index in 3:
		_orbit_legend.draw_line(Vector2(next_left + dash_index * 4, 5), Vector2(next_left + dash_index * 4 + 2, 5), PixelGlyphs.COLOR_GOOD_GREEN, 1.0)
	next_left += 13.0
	next_left += PixelGlyphs.draw_text(_orbit_legend, Vector2(next_left, 1), "target", ScreenLayout.COLOR_TEXT_LIGHT) + 8.0
	_orbit_legend.draw_line(Vector2(next_left, 5), Vector2(next_left + 10, 5), OrbitSchematic.COLOR_ACHIEVED_ORBIT, 2.0)
	next_left += 13.0
	next_left += PixelGlyphs.draw_text(_orbit_legend, Vector2(next_left, 1), "achieved", ScreenLayout.COLOR_TEXT_LIGHT) + 8.0
	var miss_kilometers: float = _schematic.altitude_miss_kilometers()
	if is_nan(miss_kilometers):
		if not GameState.mission.is_empty():
			PixelGlyphs.draw_chip(_orbit_legend, Vector2(next_left, 1), "lamp_blocking", "no orbit", ScreenLayout.COLOR_WARNING_RED)
		return
	var tolerance_kilometers: float = GameState.mission.get("target", {}).get("altitude_tolerance_kilometers", 0.0)
	var is_inside_tolerance: bool = absf(miss_kilometers) <= tolerance_kilometers
	# Its own glyph; "in tol." or "off tol." says in words what the colour repeats.
	PixelGlyphs.draw_chip(_orbit_legend, Vector2(next_left, 1), "gap",
			"%skm %s" % [NumberFormat.signed_difference(miss_kilometers), "in tol." if is_inside_tolerance else "off tol."],
			OrbitSchematic.COLOR_ACHIEVED_ORBIT, ScreenLayout.COLOR_TEXT_LIGHT)


func _timeline_strip_rect() -> Rect2:
	return Rect2(16, 24, TIMELINE_PANEL_RECT.size.x - 32, 20)


func _timeline_duration_seconds() -> float:
	var duration_seconds: float = 0.0
	if _result != null:
		duration_seconds = _result.flight_duration_seconds
		for event in _result.event_log:
			duration_seconds = maxf(duration_seconds, float(event.get("time_seconds", 0.0)))
	if duration_seconds <= 0.0:
		duration_seconds = float(GameState.mission.get("duration_seconds", 1.0))
	return maxf(duration_seconds, 1.0)


## The x of an event's pip. duration_seconds comes from
## _timeline_duration_seconds(), computed once by the caller.
func _pip_x(event: Dictionary, duration_seconds: float) -> float:
	var strip_rect: Rect2 = _timeline_strip_rect()
	return roundf(strip_rect.position.x + strip_rect.size.x * clampf(float(event.get("time_seconds", 0.0)) / duration_seconds, 0.0, 1.0))


func _draw_timeline() -> void:
	var event_count: int = _result.event_log.size() if _result != null else 0
	var title_width: float = PixelGlyphs.draw_text(_timeline, Vector2(8, 4), "EVENTS", COLOR_HEADER, PixelGlyphs.TITLE_SIZE_PIXELS)
	var next_left: float = 8.0 + title_width + 6.0
	next_left += PixelGlyphs.draw_text(_timeline, Vector2(next_left, 6), "%d" % event_count, ScreenLayout.COLOR_TEXT_LIGHT) + 6.0
	next_left += PixelGlyphs.draw_placeholder_badge(_timeline, Vector2(next_left, 6)) + 8.0
	for legend_entry in [[WarningLamps.Severity.OK, "safe"], [WarningLamps.Severity.WARNING, "watch"], [WarningLamps.Severity.BLOCKING, "damage"]]:
		next_left += PixelGlyphs.draw_chip(_timeline, Vector2(next_left, 6), PixelGlyphs.lamp_glyph_name(legend_entry[0]), legend_entry[1],
				PixelGlyphs.lamp_color(legend_entry[0]), PixelGlyphs.COLOR_MUTED_TEXT) + 8.0
	PixelGlyphs.draw_text(_timeline, Vector2(TIMELINE_PANEL_RECT.size.x - 140, 6), "score bonus: none", PixelGlyphs.COLOR_MUTED_TEXT)

	var strip_rect: Rect2 = _timeline_strip_rect()
	var axis_y: float = strip_rect.get_center().y
	_timeline.draw_line(Vector2(strip_rect.position.x, axis_y), Vector2(strip_rect.end.x, axis_y), ScreenLayout.COLOR_MONITOR_GRID_LINE, 1.0)
	for end_x in [strip_rect.position.x, strip_rect.end.x]:
		_timeline.draw_line(Vector2(end_x, axis_y - 4), Vector2(end_x, axis_y + 4), ScreenLayout.COLOR_MONITOR_GRID_LINE, 1.0)
	PixelGlyphs.draw_text(_timeline, Vector2(strip_rect.position.x - 4, strip_rect.end.y + 2), "0s", PixelGlyphs.COLOR_MUTED_TEXT)
	var duration_seconds: float = _timeline_duration_seconds()
	var end_text := NumberFormat.duration(duration_seconds)
	PixelGlyphs.draw_text(_timeline, Vector2(strip_rect.end.x - PixelGlyphs.text_width(end_text) + 4, strip_rect.end.y + 2), end_text, PixelGlyphs.COLOR_MUTED_TEXT)
	if event_count == 0:
		PixelGlyphs.draw_text(_timeline, Vector2(strip_rect.get_center().x - 40, axis_y - 12), "no events recorded", PixelGlyphs.COLOR_MUTED_TEXT)
		return
	for event_index in event_count:
		var event: Dictionary = _result.event_log[event_index]
		var severity: int = MissionPresentation.event_severity(event)
		var pip_x: float = _pip_x(event, duration_seconds)
		PixelGlyphs.draw_glyph(_timeline, PixelGlyphs.lamp_glyph_name(severity), Vector2(pip_x - 3, axis_y - 3), PixelGlyphs.lamp_color(severity))
		if event_index == _selected_event_index:
			_timeline.draw_rect(Rect2(pip_x - 5, axis_y - 5, 11, 11), ScreenLayout.COLOR_ACCENT_ORANGE, false, 1.0)
		if event_index == _focused_event_index and _timeline.has_focus():
			_timeline.draw_rect(Rect2(pip_x - 7, axis_y - 7, 15, 15), ScreenLayout.COLOR_MONITOR_GRID_LINE, false, 1.0)
	if _hovered_event_index >= 0 and _hovered_event_index < event_count:
		var hovered_event: Dictionary = _result.event_log[_hovered_event_index]
		var bubble_text := "%s · %s" % [_event_title(hovered_event), hovered_event.get("outcome", "Unrecorded")]
		var bubble_width: float = PixelGlyphs.text_width(bubble_text) + 6.0
		var bubble_left: float = clampf(_pip_x(hovered_event, duration_seconds) - bubble_width * 0.5, 2.0, TIMELINE_PANEL_RECT.size.x - bubble_width - 2.0)
		var bubble_rect := Rect2(roundf(bubble_left), strip_rect.end.y + 1, bubble_width, 11)
		_timeline.draw_rect(bubble_rect, Color(ScreenLayout.COLOR_SPACE_BLACK, 0.95))
		_timeline.draw_rect(bubble_rect, ScreenLayout.COLOR_MONITOR_GRID_LINE, false, 1.0)
		PixelGlyphs.draw_text(_timeline, bubble_rect.position + Vector2(3, 1), bubble_text, ScreenLayout.COLOR_TEXT_LIGHT)


func _event_title(event: Dictionary) -> String:
	var event_id: String = event.get("event_type_id", "unknown")
	var event_name: String = GameData.event_type(event_id).get("name", event_id)
	return "%s %s" % [NumberFormat.duration(float(event.get("time_seconds", 0.0))), event_name]


func _group_index_at(local_position: Vector2) -> int:
	if _score == null or _score.is_launch_failure:
		return -1
	var group_index: int = floori((local_position.y - BAR_ROW_TOP_PIXELS + 2.0) / BAR_ROW_HEIGHT_PIXELS)
	if group_index < 0 or group_index >= score_groups.size():
		return -1
	return group_index


func _event_index_at(local_position: Vector2) -> int:
	if _result == null:
		return -1
	var strip_rect: Rect2 = _timeline_strip_rect()
	if absf(local_position.y - strip_rect.get_center().y) > 8.0:
		return -1
	var nearest_index := -1
	var nearest_distance: float = PIP_HIT_DISTANCE_PIXELS
	var duration_seconds: float = _timeline_duration_seconds()
	for event_index in _result.event_log.size():
		var distance: float = absf(_pip_x(_result.event_log[event_index], duration_seconds) - local_position.x)
		if distance <= nearest_distance:
			nearest_distance = distance
			nearest_index = event_index
	return nearest_index


func _on_bars_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var group_index: int = _group_index_at(motion_event.position)
		if group_index != _hovered_group_index:
			_hovered_group_index = group_index
			_bars.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND if group_index >= 0 else Control.CURSOR_ARROW
			_bars.queue_redraw()
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var group_index: int = _group_index_at(button_event.position)
			if group_index >= 0:
				select_group(-1 if group_index == _selected_group_index else group_index)
	elif event is InputEventKey and event.is_pressed():
		if event.is_action_pressed("ui_down"):
			focus_group(_focused_group_index + 1)
			_bars.accept_event()
		elif event.is_action_pressed("ui_up"):
			focus_group(_focused_group_index - 1)
			_bars.accept_event()
		elif event.is_action_pressed("ui_accept") and _focused_group_index >= 0:
			select_group(-1 if _focused_group_index == _selected_group_index else _focused_group_index)
			_bars.accept_event()


func _on_bars_mouse_exited() -> void:
	_hovered_group_index = -1
	_bars.queue_redraw()


func _on_timeline_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var event_index: int = _event_index_at(motion_event.position)
		if event_index != _hovered_event_index:
			hover_event(event_index)
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var event_index: int = _event_index_at(button_event.position)
			if event_index >= 0:
				select_event(-1 if event_index == _selected_event_index else event_index)
	elif event is InputEventKey and event.is_pressed():
		if event.is_action_pressed("ui_right"):
			focus_event(_focused_event_index + 1)
			_timeline.accept_event()
		elif event.is_action_pressed("ui_left"):
			focus_event(_focused_event_index - 1)
			_timeline.accept_event()
		elif event.is_action_pressed("ui_accept") and _focused_event_index >= 0:
			select_event(-1 if _focused_event_index == _selected_event_index else _focused_event_index)
			_timeline.accept_event()
