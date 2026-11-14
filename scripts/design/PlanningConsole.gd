extends Control
## The PLANNING half of the console: the overview with the rocket monitor and
## the orbit monitor, the three stat chips, the Launch button, and the zoom
## into the rocket design screen and the orbit planning screen.
## Requirements: context/plan_draft.md, section "PLANNING half".
##
## STUB(T06): shows the overview mock-up, a live orbit monitor, one button
## that builds a fixed example rocket and the Launch button. No zoom, no chips.
## T06 replaces this file.

var _orbit_monitor: OrbitView
var _status_label: Label
var _launch_button: Button


func _ready() -> void:
	size = ScreenLayout.SCREEN_SIZE

	var background := TextureRect.new()
	background.texture = load(ScreenLayout.PLANNING_OVERVIEW_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)

	_orbit_monitor = OrbitView.new()
	_orbit_monitor.position = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.position
	_orbit_monitor.size = ScreenLayout.OVERVIEW_ORBIT_MONITOR_SCREEN.size
	_orbit_monitor.clip_contents = true
	add_child(_orbit_monitor)

	var top_bezel: Rect2 = ScreenLayout.OVERVIEW_TOP_BEZEL

	var example_rocket_button := Button.new()
	example_rocket_button.text = "Build example rocket"
	example_rocket_button.position = top_bezel.position
	example_rocket_button.size = Vector2(170, 26)
	example_rocket_button.pressed.connect(_on_build_example_rocket_pressed)
	add_child(example_rocket_button)

	_launch_button = Button.new()
	_launch_button.text = "LAUNCH"
	_launch_button.position = top_bezel.position + Vector2(180, 0)
	_launch_button.size = Vector2(90, 26)
	_launch_button.pressed.connect(_on_launch_pressed)
	add_child(_launch_button)

	_status_label = Label.new()
	_status_label.position = top_bezel.position + Vector2(0, 30)
	_status_label.size = Vector2(top_bezel.size.x, 44)
	_status_label.add_theme_font_size_override("font_size", 10)
	add_child(_status_label)

	GameState.derived_changed.connect(_refresh)
	_refresh()


func _on_build_example_rocket_pressed() -> void:
	var design: RocketDesign = GameState.design
	if design.stages.is_empty():
		var first_stage: Stage = design.add_stage("engine_liquid_basic", "tank_aluminium_basic")
		design.payload_part_ids.append("telemetry_altimeter_basic")
		design.payload_part_ids.append("science_camera_basic")
		GameState.plan.launch_stage_ids.append(first_stage.stage_id)
	GameState.notify_design_changed()


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
	_launch_button.disabled = not summary.warnings.is_empty()
	_status_label.text = "Cost %.1f of %.1f million USD   Weight %.0f kg\n%s" % [
			summary.cost_million_usd,
			GameState.budget_million_usd,
			summary.wet_mass_kilograms,
			" ".join(PackedStringArray(summary.warnings))]

	# The overview monitor is small, so it uses a smaller scale than the mission's own.
	var overview_display := {"display": {"body_radius_pixels": 45.0, "pixels_per_kilometer": 0.05}}
	_orbit_monitor.configure(GameData.body(GameState.mission.get("body_id", "earth")), overview_display)
	_orbit_monitor.show_trajectory(GameState.trajectory)
