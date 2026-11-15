extends Control
## The PLANNING half of the console: the overview with the rocket monitor and
## the orbit monitor, the three stat chips, the Launch button, and the zoom
## into the rocket design screen and the orbit planning screen.
## Requirements: context/plan_draft.md, section "PLANNING half".
##
## Structure:
##   overview layer      background, the two monitors, chips, Launch, messages
##   two detail holders  each holds one detail scene plus its own stat chips;
##                       ZoomTransition grows a holder from its monitor
##   back button         in ScreenLayout.BACK_BUTTON_RECT, only while zoomed
## Everything shown comes from GameState.summary and GameState.trajectory and
## is redrawn when GameState.derived_changed arrives.
## ScreenLayout.CONSOLE_SWITCH_RECT is left empty: Console draws its switch there.

enum Screen { OVERVIEW, ROCKET_DESIGN, ORBIT_PLANNING }

const ROCKET_DESIGN_SCENE := preload("res://scenes/planning/RocketDesign.tscn")
const ORBIT_PLANNING_SCENE := preload("res://scenes/planning/OrbitPlanning.tscn")

## Chips of the rocket design screen: the bezel above the part list and the
## tabs, which the mock-up leaves empty. Clear of CONSOLE_SWITCH_RECT.
const ROCKET_DESIGN_STAT_CHIP_RECTS: Array[Rect2] = [
	Rect2(300, 6, 68, 38),
	Rect2(372, 6, 68, 38),
	Rect2(444, 6, 72, 38),
]
const LAUNCH_BUTTON_SIZE := Vector2(84, 28)
const EXAMPLE_BUTTON_SIZE := Vector2(132, 28)
const BUTTON_GAP_PIXELS := 6.0
const MESSAGE_FONT_SIZE_PIXELS := 8
const BUTTON_FONT_SIZE_PIXELS := 10
const BACK_BUTTON_FONT_SIZE_PIXELS := 8
const LAMP_BAR_HEIGHT_PIXELS := 13.0
## Scale of the orbit view on the small overview monitor.
const OVERVIEW_BODY_RADIUS_PIXELS := 45.0
const OVERVIEW_PIXELS_PER_KILOMETER := 0.05

const MESSAGE_NO_MISSION := "No mission selected."
const MESSAGE_READY := "Ready to launch."
const MESSAGE_LAUNCHED := "The flight has started. The rocket and the plan can no longer change."
const HINT_ZOOM := "Click a monitor to open it."

## The screen shown now, or the one a running zoom is moving to.
var current_screen: Screen = Screen.OVERVIEW
## Length of the zoom animation. Zero switches at once (used by the tests).
var zoom_duration_seconds: float = ZoomTransition.DEFAULT_DURATION_SECONDS
var launch_button: Button
var overview_stat_chips: StatChips
var rocket_design_screen: Control
var orbit_planning_screen: Control
var back_button: Button

var _overview: Control
var _rocket_monitor_preview: RocketStackPreview
var _orbit_monitor: OrbitView
var _message_label: RichTextLabel
## Warning lamps of the plan, with the "✖1 ▲2" summary, above the message line.
var _lamp_bar: LampBar
var _lamps: Array[Dictionary] = []
## The sentence of the lamp the player points at or pinned; "" for none.
var _active_lamp_sentence: String = ""
var _active_lamp_severity: int = WarningLamps.Severity.OK
var _rocket_design_holder: Control
var _orbit_planning_holder: Control
var _all_stat_chips: Array[StatChips] = []
var _input_blocker: Control
var _is_zoom_running: bool = false


func _ready() -> void:
	# The layout is fixed to the mock-ups, so it must not mirror itself on a
	# computer whose language is written right to left.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = ScreenLayout.SCREEN_SIZE
	clip_contents = true

	_create_overview()

	rocket_design_screen = ROCKET_DESIGN_SCENE.instantiate()
	_rocket_design_holder = _create_detail_holder(rocket_design_screen, ROCKET_DESIGN_STAT_CHIP_RECTS, true)
	orbit_planning_screen = ORBIT_PLANNING_SCENE.instantiate()
	_orbit_planning_holder = _create_detail_holder(
			orbit_planning_screen, ScreenLayout.ORBIT_PLANNING_STAT_CHIP_SCREENS, false)

	back_button = Button.new()
	back_button.text = "< BACK"
	back_button.tooltip_text = "Back to the overview (Esc)"
	back_button.position = ScreenLayout.BACK_BUTTON_RECT.position
	back_button.focus_mode = Control.FOCUS_NONE
	# The rectangle is only 22 pixels high, so the text is one size smaller.
	back_button.add_theme_font_size_override("font_size", BACK_BUTTON_FONT_SIZE_PIXELS)
	back_button.pressed.connect(zoom_back_to_overview)
	back_button.hide()
	add_child(back_button)
	_set_size_when_font_is_known(back_button, ScreenLayout.BACK_BUTTON_RECT.size)

	# Catches every click while a zoom animation runs.
	_input_blocker = Control.new()
	_input_blocker.size = ScreenLayout.SCREEN_SIZE
	_input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	_input_blocker.hide()
	add_child(_input_blocker)

	GameState.derived_changed.connect(_refresh)
	# Launching changes no summary, so it sends no derived_changed of its own.
	GameState.launch_requested.connect(_refresh)
	_refresh()


func zoom_into_rocket_design() -> void:
	_zoom_into(Screen.ROCKET_DESIGN)


func zoom_into_orbit_planning() -> void:
	_zoom_into(Screen.ORBIT_PLANNING)


## Returns from a detail screen to the overview. Does nothing on the overview
## or while a zoom animation runs.
func zoom_back_to_overview() -> void:
	if current_screen == Screen.OVERVIEW or _is_zoom_running:
		return
	var holder: Control = _holder_of(current_screen)
	var monitor_rect: Rect2 = _monitor_rect_of(current_screen)
	current_screen = Screen.OVERVIEW
	back_button.hide()
	_run_zoom(ZoomTransition.zoom_out(holder, _overview, monitor_rect, zoom_duration_seconds))


func _unhandled_input(event: InputEvent) -> void:
	if current_screen == Screen.OVERVIEW or not is_on_screen():
		return
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		zoom_back_to_overview()


## False while the console shell shows the EXECUTION half: Console slides this
## scene out of the window but never hides it, so visibility alone cannot tell.
func is_on_screen() -> bool:
	if not is_visible_in_tree():
		return false
	return get_global_rect().intersects(get_viewport_rect())


func _zoom_into(target_screen: Screen) -> void:
	if current_screen != Screen.OVERVIEW or _is_zoom_running:
		return
	current_screen = target_screen
	var zoom_tween: Tween = ZoomTransition.zoom_in(
			_holder_of(target_screen), _overview, _monitor_rect_of(target_screen), zoom_duration_seconds)
	_run_zoom(zoom_tween)


## Blocks input until the tween ends. A null tween means the zoom is already done.
func _run_zoom(zoom_tween: Tween) -> void:
	if zoom_tween == null:
		_on_zoom_finished()
		return
	_is_zoom_running = true
	_input_blocker.show()
	zoom_tween.finished.connect(_on_zoom_finished)


func _on_zoom_finished() -> void:
	_is_zoom_running = false
	_input_blocker.hide()
	back_button.visible = current_screen != Screen.OVERVIEW


## A Button cannot be made smaller than its text, and it measures its text
## with the small font only after the theme has been applied, which Godot does
## at the end of the frame. So the size is set now and once more, deferred.
func _set_size_when_font_is_known(button: Button, wanted_size: Vector2) -> void:
	button.size = wanted_size
	button.set_deferred("size", wanted_size)


func _holder_of(screen: Screen) -> Control:
	if screen == Screen.ROCKET_DESIGN:
		return _rocket_design_holder
	return _orbit_planning_holder


func _monitor_rect_of(screen: Screen) -> Rect2:
	if screen == Screen.ROCKET_DESIGN:
		return ScreenLayout.OVERVIEW_ROCKET_MONITOR_SCREEN
	return ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN


func _create_overview() -> void:
	_overview = Control.new()
	_overview.size = ScreenLayout.SCREEN_SIZE
	_overview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_overview)

	var background := TextureRect.new()
	background.texture = load(ScreenLayout.PLANNING_OVERVIEW_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = ScreenLayout.SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(background)

	var rocket_monitor_rect: Rect2 = ScreenLayout.OVERVIEW_ROCKET_MONITOR_SCREEN
	_rocket_monitor_preview = RocketStackPreview.new()
	_rocket_monitor_preview.is_interactive = false
	_rocket_monitor_preview.position = rocket_monitor_rect.position
	_rocket_monitor_preview.size = rocket_monitor_rect.size
	_overview.add_child(_rocket_monitor_preview)
	_overview.add_child(_create_monitor_button(
			rocket_monitor_rect, "Open the rocket design screen", zoom_into_rocket_design))

	var orbit_monitor_rect: Rect2 = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN
	_orbit_monitor = OrbitView.new()
	_orbit_monitor.position = orbit_monitor_rect.position
	_orbit_monitor.size = orbit_monitor_rect.size
	_orbit_monitor.clip_contents = true
	_orbit_monitor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(_orbit_monitor)
	_overview.add_child(_create_monitor_button(
			orbit_monitor_rect, "Open the orbit planning screen", zoom_into_orbit_planning))

	overview_stat_chips = StatChips.new()
	overview_stat_chips.configure(ScreenLayout.OVERVIEW_STAT_CHIP_SCREENS, false)
	_overview.add_child(overview_stat_chips)
	_all_stat_chips.append(overview_stat_chips)

	_create_top_bezel()


func _create_top_bezel() -> void:
	var top_bezel: Rect2 = ScreenLayout.OVERVIEW_TOP_BEZEL

	launch_button = Button.new()
	launch_button.text = "LAUNCH"
	launch_button.position = top_bezel.position + Vector2(0, 2)
	launch_button.focus_mode = Control.FOCUS_NONE
	launch_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE_PIXELS)
	launch_button.add_theme_color_override("font_color", ScreenLayout.COLOR_ACCENT_ORANGE)
	launch_button.pressed.connect(_on_launch_pressed)
	_overview.add_child(launch_button)
	_set_size_when_font_is_known(launch_button, LAUNCH_BUTTON_SIZE)

	var example_rocket_button := Button.new()
	example_rocket_button.text = "Build example rocket"
	example_rocket_button.tooltip_text = "Replaces the rocket and the plan with a worked example that reaches orbit"
	example_rocket_button.position = launch_button.position + Vector2(LAUNCH_BUTTON_SIZE.x + BUTTON_GAP_PIXELS, 0)
	example_rocket_button.focus_mode = Control.FOCUS_NONE
	example_rocket_button.add_theme_font_size_override("font_size", BUTTON_FONT_SIZE_PIXELS)
	example_rocket_button.pressed.connect(_on_build_example_rocket_pressed)
	_overview.add_child(example_rocket_button)
	_set_size_when_font_is_known(example_rocket_button, EXAMPLE_BUTTON_SIZE)

	var buttons_right_pixels: float = example_rocket_button.position.x + EXAMPLE_BUTTON_SIZE.x + BUTTON_GAP_PIXELS
	var hint_label := Label.new()
	hint_label.text = HINT_ZOOM
	hint_label.position = Vector2(buttons_right_pixels, top_bezel.position.y + 2)
	hint_label.size = Vector2(top_bezel.end.x - buttons_right_pixels, LAUNCH_BUTTON_SIZE.y)
	hint_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	hint_label.clip_text = true
	hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hint_label.add_theme_font_size_override("font_size", MESSAGE_FONT_SIZE_PIXELS)
	hint_label.add_theme_color_override("font_color", ScreenLayout.COLOR_SPACE_BLACK)
	_overview.add_child(hint_label)

	var lamps_top_pixels: float = launch_button.position.y + LAUNCH_BUTTON_SIZE.y + 2.0
	_lamp_bar = LampBar.new()
	_lamp_bar.position = Vector2(top_bezel.position.x, lamps_top_pixels)
	_lamp_bar.size = Vector2(top_bezel.size.x, LAMP_BAR_HEIGHT_PIXELS)
	_lamp_bar.tooltip_text = "Warning lamps: hover one for its reason, click to pin it, Tab to step through."
	_lamp_bar.active_sentence_changed.connect(_on_active_lamp_changed)
	_overview.add_child(_lamp_bar)

	# One line for the sentence of the lamp under the mouse (or the worst one).
	var messages_top_pixels: float = lamps_top_pixels + LAMP_BAR_HEIGHT_PIXELS + 1.0
	_message_label = RichTextLabel.new()
	_message_label.bbcode_enabled = true
	_message_label.position = Vector2(top_bezel.position.x, messages_top_pixels)
	_message_label.size = Vector2(top_bezel.size.x, top_bezel.end.y - messages_top_pixels)
	_message_label.scroll_active = false
	_message_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_message_label.add_theme_font_size_override("normal_font_size", MESSAGE_FONT_SIZE_PIXELS)
	_message_label.add_theme_constant_override("line_separation", -1)
	var message_style := StyleBoxFlat.new()
	message_style.bg_color = Color(ScreenLayout.COLOR_SPACE_BLACK, 0.55)
	message_style.set_content_margin_all(2)
	_message_label.add_theme_stylebox_override("normal", message_style)
	_overview.add_child(_message_label)


## A see-through button over a monitor: a light frame appears under the mouse.
func _create_monitor_button(monitor_rect: Rect2, tooltip: String, on_pressed: Callable) -> Button:
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(ScreenLayout.COLOR_TEXT_LIGHT, 0.08)
	hover_style.border_color = ScreenLayout.COLOR_ACCENT_ORANGE
	hover_style.set_border_width_all(2)
	var empty_style := StyleBoxEmpty.new()

	var monitor_button := Button.new()
	monitor_button.position = monitor_rect.position
	monitor_button.size = monitor_rect.size
	monitor_button.tooltip_text = tooltip
	monitor_button.focus_mode = Control.FOCUS_NONE
	monitor_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	monitor_button.add_theme_stylebox_override("normal", empty_style)
	monitor_button.add_theme_stylebox_override("hover", hover_style)
	monitor_button.add_theme_stylebox_override("pressed", hover_style)
	monitor_button.pressed.connect(on_pressed)
	return monitor_button


## Wraps a detail scene and its stat chips in one Control that ZoomTransition
## moves and scales. Hidden until the player zooms in.
func _create_detail_holder(detail_screen: Control, chip_rects: Array[Rect2], draws_chip_background: bool) -> Control:
	var holder := Control.new()
	holder.size = ScreenLayout.SCREEN_SIZE
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	holder.hide()
	add_child(holder)
	holder.add_child(detail_screen)

	var stat_chips := StatChips.new()
	stat_chips.configure(chip_rects, draws_chip_background)
	holder.add_child(stat_chips)
	_all_stat_chips.append(stat_chips)
	return holder


func _on_build_example_rocket_pressed() -> void:
	if GameState.mission.is_empty() or GameState.has_launched:
		return
	ExampleFlight.fill_reference_flight(GameState.design, GameState.plan, GameState.mission)
	GameState.notify_design_changed()
	GameState.notify_plan_changed()


func _on_launch_pressed() -> void:
	# One flight per game: a second launch would restart the flight in the air.
	if GameState.has_launched:
		return
	GameState.request_launch()


func _refresh() -> void:
	var summary: PlanSummary = GameState.summary
	for stat_chips in _all_stat_chips:
		stat_chips.refresh(summary, GameState.budget_million_usd)
	_lamps = WarningLamps.lamps_from_summary(summary)
	_rocket_monitor_preview.show_design(GameState.design)
	_rocket_monitor_preview.show_lamps(_lamps)
	_lamp_bar.set_lamps(_lamps)

	if summary == null:
		launch_button.disabled = true
		launch_button.tooltip_text = MESSAGE_NO_MISSION
		_message_label.text = MESSAGE_NO_MISSION
		return

	# The Launch button is disabled only when the rocket cannot fly at all.
	# Going over budget is allowed; it costs score points instead.
	# Advice ("Warning: ...") is shown but does not block it.
	# After the launch it is disabled too, because the flight is already running.
	var blocking_problems: Array[String] = summary.blocking_problems
	launch_button.disabled = GameState.has_launched or not blocking_problems.is_empty()
	if GameState.has_launched:
		launch_button.tooltip_text = MESSAGE_LAUNCHED
	elif blocking_problems.is_empty():
		launch_button.tooltip_text = "Start the flight"
	else:
		launch_button.tooltip_text = "Cannot launch: " + " ".join(PackedStringArray(blocking_problems))
	_update_message()

	# The overview monitor is small, so it uses a smaller scale than the mission's own.
	var overview_display := {"display": {
		"body_radius_pixels": OVERVIEW_BODY_RADIUS_PIXELS,
		"pixels_per_kilometer": OVERVIEW_PIXELS_PER_KILOMETER,
	}}
	_orbit_monitor.configure(GameData.body(GameState.mission.get("body_id", "earth")), overview_display)
	# A rocket that cannot leave the pad has a path of zero length, which
	# OrbitView cannot draw without engine warnings. The monitor then shows
	# the body alone.
	var has_flight_path: bool = summary.burnout_speed_meters_per_second > 0.0
	_orbit_monitor.show_trajectory(GameState.trajectory if has_flight_path else null)


## One line under the lamps: after the launch, the launch message; otherwise
## the sentence of the lamp under the mouse, pinned or focused, else the
## worst lamp's sentence, else "Ready to launch.". Blocking sentences are red
## and start with a cross, warnings amber with a triangle: shape and colour both.
func _update_message() -> void:
	if GameState.summary == null:
		_message_label.text = MESSAGE_NO_MISSION
		return
	if GameState.has_launched:
		_message_label.text = MESSAGE_LAUNCHED
		return
	var sentence := _active_lamp_sentence
	var severity := _active_lamp_severity
	if sentence.is_empty() and not _lamps.is_empty():
		sentence = _lamps[0]["sentence"]
		severity = _lamps[0]["severity"]
	_message_label.text = message_line(sentence, severity)


## The BBCode of the message line for one lamp sentence ("" means ready).
static func message_line(sentence: String, severity: int) -> String:
	if sentence.is_empty():
		return MESSAGE_READY
	var color_code: String = PixelGlyphs.lamp_color(severity).to_html(false)
	var mark := "x" if severity == WarningLamps.Severity.BLOCKING else "!"
	var lead := "Cannot launch: " if severity == WarningLamps.Severity.BLOCKING else ""
	return "[color=#%s][b]%s[/b] %s%s[/color]" % [color_code, mark, lead, sentence.replace("[", "[lb]")]


func _on_active_lamp_changed(sentence: String, severity: int) -> void:
	_active_lamp_sentence = sentence
	_active_lamp_severity = severity
	_update_message()
