extends Control
## The PLANNING half of the console: the overview with the rocket monitor and
## the orbit monitor, the three stat chips, the Launch button, and the zoom
## into the rocket design screen and the orbit planning screen.
## Requirements: context/plan_draft.md, section "PLANNING half".
##
## STUB(T06): shows the overview mock-up, a live orbit monitor, one button
## that builds an example rocket. T05 supplies orbit-editor access, Back and shared chips; rocket construction remains T06.
## T06 replaces this file.

var _overview: Control
var _orbit_planning: Control
var _planning_stats: Control
var _back_button: Button
var _chip_labels: Array[Label] = []
var _overview_chip_labels: Array[Label] = []
var _rocket_preview: Control
var _stage_summary: Label

var _orbit_monitor: OrbitView
var _status_label: Label
var _launch_button: Button


func _ready() -> void:
	size = ScreenLayout.SCREEN_SIZE
	theme = PlanningStyle.create_theme()
	_overview = Control.new()
	_overview.size = size
	add_child(_overview)

	var background := TextureRect.new()
	background.name = "AmitPlanningBackground"
	background.texture = load(ScreenLayout.PLANNING_OVERVIEW_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.size = ScreenLayout.SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_overview.add_child(background)

	_orbit_monitor = OrbitView.new()
	_orbit_monitor.position = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.position
	_orbit_monitor.size = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.size
	_orbit_monitor.clip_contents = true
	_overview.add_child(_orbit_monitor)

	var top_bezel: Rect2 = ScreenLayout.OVERVIEW_TOP_BEZEL

	var example_rocket_button := Button.new()
	example_rocket_button.theme = theme
	example_rocket_button.text = "Load example rocket"
	example_rocket_button.position = top_bezel.position
	example_rocket_button.size = Vector2(170, 26)
	example_rocket_button.pressed.connect(_on_build_example_rocket_pressed)
	_overview.add_child(example_rocket_button)

	_launch_button = Button.new()
	_launch_button.theme = theme
	_launch_button.text = "LAUNCH"
	_launch_button.position = top_bezel.position + Vector2(180, 0)
	_launch_button.size = Vector2(90, 26)
	_launch_button.pressed.connect(_on_launch_pressed)
	_overview.add_child(_launch_button)

	_status_label = Label.new()
	_status_label.position = top_bezel.position + Vector2(0, 30)
	_status_label.size = Vector2(top_bezel.size.x, 44)
	_status_label.add_theme_font_size_override("font_size", 9 if _chip_labels.size() == 2 else 10)
	_overview.add_child(_status_label)

	_create_overview_visuals()
	_create_orbit_access()
	GameState.derived_changed.connect(_refresh)
	_refresh()


func _on_build_example_rocket_pressed() -> void:
	if GameState.mission.is_empty():
		return
	ExampleFlight.fill_automatic_flight(GameState.design, GameState.plan)
	GameState.notify_design_changed()
	GameState.notify_plan_changed()


func _on_launch_pressed() -> void:
	GameState.request_launch()


func _refresh() -> void:
	var summary: PlanSummary = GameState.summary
	if summary == null:
		_status_label.text = "No mission selected."
		_launch_button.disabled = true
		return

	# The Launch button is disabled only when the rocket cannot fly at all.
	# Going over budget is allowed; it costs score points instead.
	# Advice ("Warning: ...") is shown but does not block it.
	_launch_button.disabled = not summary.blocking_problems.is_empty()
	var explanation: String = summary.blocking_problems[0] if not summary.blocking_problems.is_empty() else "Open Plan flight to place manoeuvres, then launch."
	if summary.ascent != null and summary.ascent.failure_reason != "":
		explanation = summary.ascent.failure_reason
	_status_label.text = str(GameState.mission.get("name", "Mission")) + "\n" + explanation
	_rocket_preview.queue_redraw()
	var stage_lines := PackedStringArray()
	for stage_index in GameState.design.stages.size():
		var stage: Stage = GameState.design.stages[stage_index]
		stage_lines.append("%d  %s\n%s" % [stage_index + 1,
				str(GameData.part(stage.engine_part_id).get("name", "Engine")).split("(")[0].strip_edges(),
				"Solid" if SequentialPropulsion.is_solid(stage) else "Liquid"])
	_stage_summary.text = "STAGE ORDER\n\n" + "\n\n".join(stage_lines)
	if _overview_chip_labels.size() == 3:
		_overview_chip_labels[0].text = "COST\n$%.1fM" % summary.cost_million_usd
		_overview_chip_labels[1].text = "TOTAL Δv\n%.0f m/s" % summary.total_delta_v_meters_per_second
		_overview_chip_labels[2].text = "LAUNCH MASS\n%.0f kg" % summary.wet_mass_kilograms

	if _chip_labels.size() == 3:
		_chip_labels[0].text = "COST\n$%.1fM / $%.1fM" % [summary.cost_million_usd, GameState.budget_million_usd]
		_chip_labels[1].text = "TOTAL Δv\n%.0f m/s" % summary.total_delta_v_meters_per_second
		_chip_labels[2].text = "LAUNCH MASS\n%.0f kg wet / %.0f kg dry" % [summary.wet_mass_kilograms, summary.dry_mass_kilograms]
	_orbit_monitor.configure(GameData.body(GameState.mission.get("body_id", "earth")), GameState.mission)
	_orbit_monitor.show_trajectory(GameState.trajectory)


func _create_orbit_access() -> void:
	var monitor_button := Button.new()
	monitor_button.position = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.position
	monitor_button.size = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.size
	monitor_button.flat = true
	monitor_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	monitor_button.add_theme_stylebox_override("hover", PlanningStyle.panel_style(Color(0, 0, 0, 0), ScreenLayout.COLOR_ACCENT_ORANGE))
	monitor_button.add_theme_stylebox_override("pressed", PlanningStyle.panel_style(Color(0, 0, 0, 0), ScreenLayout.COLOR_ACCENT_ORANGE))
	monitor_button.tooltip_text = "Open flight planner"
	monitor_button.pressed.connect(_open_orbit_planning)
	_overview.add_child(monitor_button)
	var plan_button := Button.new()
	plan_button.theme = theme
	plan_button.text = "Plan flight"
	plan_button.position = ScreenLayout.OVERVIEW_TOP_BEZEL.position + Vector2(280, 0)
	plan_button.size = Vector2(140, 26)
	plan_button.pressed.connect(_open_orbit_planning)
	_overview.add_child(plan_button)
	_orbit_planning = load("res://scenes/planning/OrbitPlanning.tscn").instantiate()
	_orbit_planning.hide()
	add_child(_orbit_planning)
	_planning_stats = Control.new()
	_planning_stats.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_planning_stats.size = ScreenLayout.SCREEN_SIZE
	_planning_stats.hide()
	add_child(_planning_stats)
	for rectangle in ScreenLayout.ORBIT_PLANNING_STAT_CHIP_SCREENS:
		var backing := ColorRect.new()
		backing.position = rectangle.position
		backing.size = rectangle.size
		backing.color = ScreenLayout.COLOR_SPACE_BLACK
		backing.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_planning_stats.add_child(backing)
		var label := Label.new()
		label.position = rectangle.position + Vector2(8, 3)
		label.size = rectangle.size - Vector2(16, 6)
		label.add_theme_font_size_override("font_size", 10)
		label.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_planning_stats.add_child(label)
		_chip_labels.append(label)
	_back_button = Button.new()
	_back_button.theme = theme
	_back_button.text = "Back"
	_back_button.position = ScreenLayout.BACK_BUTTON_RECT.position
	_back_button.size = ScreenLayout.BACK_BUTTON_RECT.size
	_back_button.add_theme_font_size_override("font_size", 10)
	_back_button.pressed.connect(_show_overview)
	_back_button.hide()
	add_child(_back_button)


func _open_orbit_planning() -> void:
	_overview.hide()
	_orbit_planning.show()
	_planning_stats.show()
	_back_button.show()
	_refresh()


func _show_overview() -> void:
	_orbit_planning.hide()
	_planning_stats.hide()
	_back_button.hide()
	_overview.show()


func _unhandled_input(event: InputEvent) -> void:
	if _orbit_planning != null and _orbit_planning.is_visible_in_tree() and event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		_show_overview()
		get_viewport().set_input_as_handled()


func _create_overview_visuals() -> void:
	var heading := Label.new()
	heading.text = "PLAN"
	heading.position = Vector2(16, 8)
	heading.add_theme_font_size_override("font_size", 12)
	heading.modulate = Color("#183752")
	_overview.add_child(heading)
	var rocket_caption := Label.new()
	rocket_caption.text = "VEHICLE"
	rocket_caption.position = Vector2(80, 78)
	rocket_caption.add_theme_font_size_override("font_size", 10)
	rocket_caption.modulate = Color("#183752")
	_overview.add_child(rocket_caption)
	_rocket_preview = Control.new()
	_rocket_preview.position = ScreenLayout.OVERVIEW_ROCKET_MONITOR_SCREEN.position
	_rocket_preview.size = ScreenLayout.OVERVIEW_ROCKET_MONITOR_SCREEN.size
	_rocket_preview.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_rocket_preview.draw.connect(_draw_rocket_preview)
	_overview.add_child(_rocket_preview)
	_stage_summary = Label.new()
	_stage_summary.position = ScreenLayout.OVERVIEW_PARTS_COLUMN.position + Vector2(3, 2)
	_stage_summary.size = ScreenLayout.OVERVIEW_PARTS_COLUMN.size - Vector2(6, 4)
	_stage_summary.add_theme_font_size_override("font_size", 8)
	_stage_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stage_summary.modulate = Color("#10263c")
	_overview.add_child(_stage_summary)
	var trajectory_caption := Label.new()
	trajectory_caption.text = "ORBIT MONITOR · CLICK TO PLAN"
	trajectory_caption.position = Vector2(350, 153)
	trajectory_caption.add_theme_font_size_override("font_size", 10)
	trajectory_caption.modulate = Color("#183752")
	_overview.add_child(trajectory_caption)
	for rectangle in ScreenLayout.OVERVIEW_STAT_CHIP_SCREENS:
		var panel := ColorRect.new()
		panel.position = rectangle.position
		panel.size = rectangle.size
		panel.color = ScreenLayout.COLOR_SPACE_BLACK
		panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_overview.add_child(panel)
		var label := Label.new()
		label.position = rectangle.position + Vector2(6, 4)
		label.size = rectangle.size - Vector2(12, 8)
		label.add_theme_font_size_override("font_size", 9)
		_overview.add_child(label)
		_overview_chip_labels.append(label)


func _draw_rocket_preview() -> void:
	var drawing_size: Vector2 = _rocket_preview.size
	var font: Font = ThemeDB.fallback_font
	if GameState.design.stages.is_empty():
		_rocket_preview.draw_string(font, Vector2(14, 90), "No rocket loaded", HORIZONTAL_ALIGNMENT_LEFT, -1.0, 10, Color("#93aebf"))
		return
	var height_pixels: float = minf(44.0, 145.0 / float(GameState.design.stages.size()))
	var bottom_pixels: float = drawing_size.y - 24.0
	for stage_index in GameState.design.stages.size():
		var stage: Stage = GameState.design.stages[stage_index]
		var width_pixels: float = maxf(34.0, 66.0 - float(stage_index) * 6.0)
		var rectangle := Rect2((drawing_size.x - width_pixels) / 2.0, bottom_pixels - height_pixels, width_pixels, height_pixels - 5.0)
		var color: Color = OrbitView.stage_color(stage.stage_id)
		_rocket_preview.draw_rect(rectangle, color.darkened(0.7))
		_rocket_preview.draw_rect(rectangle, color, false, 1.0)
		_rocket_preview.draw_string(font, rectangle.position + Vector2(10, height_pixels * 0.5), "STAGE %d" % (stage_index + 1), HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, color)
		var nozzle_center := Vector2(drawing_size.x / 2.0, bottom_pixels - 4.0)
		_rocket_preview.draw_colored_polygon(PackedVector2Array([nozzle_center + Vector2(-7, 0), nozzle_center + Vector2(7, 0),
				nozzle_center + Vector2(11, 6), nozzle_center + Vector2(-11, 6)]), Color("#8da4b6"))
		bottom_pixels -= height_pixels
	_rocket_preview.draw_colored_polygon(PackedVector2Array([Vector2(drawing_size.x / 2.0 - 23, bottom_pixels),
			Vector2(drawing_size.x / 2.0, bottom_pixels - 29), Vector2(drawing_size.x / 2.0 + 23, bottom_pixels)]), Color("#c6d6e1"))
