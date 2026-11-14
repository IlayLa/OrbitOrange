extends Control
## The orbit planning screen: the orbit view where the player sets the launch
## and places pulses, and the engine list on the right.
## Requirements: context/plan_draft.md, section "Orbit / pulse planning".
## Layout: the ORBIT_PLANNING_ rectangles in ScreenLayout. The three stat chip
## rectangles are drawn by PlanningConsole and must be left empty here.
##
## STUB(T05): shows the mock-up and a read-only orbit view. T05 replaces this file.

var _orbit_view: OrbitView


func _ready() -> void:
	size = ScreenLayout.SCREEN_SIZE
	var background := TextureRect.new()
	background.texture = load(ScreenLayout.ORBIT_PLANNING_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)

	_orbit_view = OrbitView.new()
	_orbit_view.position = ScreenLayout.ORBIT_PLANNING_VIEW_SCREEN.position
	_orbit_view.size = ScreenLayout.ORBIT_PLANNING_VIEW_SCREEN.size
	_orbit_view.clip_contents = true
	add_child(_orbit_view)

	GameState.derived_changed.connect(_refresh)
	_refresh()


func _refresh() -> void:
	if GameState.mission.is_empty():
		return
	_orbit_view.configure(GameData.body(GameState.mission.get("body_id", "earth")), GameState.mission)
	_orbit_view.show_trajectory(GameState.trajectory)
