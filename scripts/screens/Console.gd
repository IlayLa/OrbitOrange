extends Control
## The control-room console: the PLANNING half and the EXECUTION half side by
## side, with a switch that slides between them. EXECUTION stays locked until
## the player launches. This script also starts the flight and moves on to the
## final screen when the flight ends. Owned by the integrator.

const PLANNING_CONSOLE_SCENE := preload("res://scenes/PlanningConsole.tscn")
const EXECUTION_CONSOLE_SCENE := preload("res://scenes/ExecutionConsole.tscn")
const SLIDE_DURATION_SECONDS := 0.4

var _sliding_container: Control
var _planning_switch_button: Button
var _execution_switch_button: Button


func _ready() -> void:
	clip_contents = true
	size = ScreenLayout.SCREEN_SIZE

	_sliding_container = Control.new()
	add_child(_sliding_container)

	var planning_console: Control = PLANNING_CONSOLE_SCENE.instantiate()
	planning_console.position = Vector2.ZERO
	_sliding_container.add_child(planning_console)

	var execution_console: Control = EXECUTION_CONSOLE_SCENE.instantiate()
	execution_console.position = Vector2(ScreenLayout.SCREEN_SIZE.x, 0)
	_sliding_container.add_child(execution_console)

	_create_switch_buttons()
	GameState.launch_requested.connect(_on_launch_requested)
	FlightSimulation.flight_ended.connect(_on_flight_ended)


func _create_switch_buttons() -> void:
	var switch_rect: Rect2 = ScreenLayout.CONSOLE_SWITCH_RECT
	var button_size := Vector2(switch_rect.size.x / 2.0, switch_rect.size.y)

	_planning_switch_button = Button.new()
	_planning_switch_button.text = "< PLAN"
	_planning_switch_button.theme = PlanningStyle.create_theme()
	_planning_switch_button.position = switch_rect.position
	_planning_switch_button.size = button_size
	_planning_switch_button.pressed.connect(show_planning_half)
	add_child(_planning_switch_button)

	_execution_switch_button = Button.new()
	_execution_switch_button.text = "EXEC >"
	_execution_switch_button.theme = PlanningStyle.create_theme()
	_execution_switch_button.position = switch_rect.position + Vector2(button_size.x, 0)
	_execution_switch_button.size = button_size
	_execution_switch_button.disabled = not GameState.has_launched
	_execution_switch_button.pressed.connect(show_execution_half)
	add_child(_execution_switch_button)


func show_planning_half() -> void:
	_slide_to(0.0)


func show_execution_half() -> void:
	_slide_to(-ScreenLayout.SCREEN_SIZE.x)


func _slide_to(target_position_x_pixels: float) -> void:
	var slide_tween: Tween = create_tween()
	slide_tween.tween_property(
			_sliding_container, "position:x", target_position_x_pixels, SLIDE_DURATION_SECONDS)


func _on_launch_requested() -> void:
	FlightSimulation.start_flight(
			GameState.design, GameState.plan, GameState.mission, GameState.random_seed)
	_execution_switch_button.disabled = false
	show_execution_half()


func _on_flight_ended(result: FlightResult) -> void:
	GameState.finish_flight(result)
	GameState.go_to_scene(GameState.FINAL_SCREEN_SCENE_PATH)
