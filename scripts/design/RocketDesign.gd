extends Control
## The rocket design screen: the rocket preview on the left, the part cards
## and the four category tabs on the right.
## Requirements: context/plan_draft.md, sections "Zoom LEFT: Rocket build" and
## "Rocket design". Layout: the ROCKET_DESIGN_ rectangles in ScreenLayout.
##
## STUB(T06): shows only the mock-up. T06 replaces this file.


func _ready() -> void:
	size = ScreenLayout.SCREEN_SIZE
	var background := TextureRect.new()
	background.texture = load(ScreenLayout.ROCKET_DESIGN_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)
