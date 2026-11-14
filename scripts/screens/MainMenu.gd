extends Control
## The first screen: logo, title and a button that starts a new game.
## Owned by the integrator.


func _ready() -> void:
	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_SPACE_BLACK
	background.size = ScreenLayout.SCREEN_SIZE
	add_child(background)

	var logo := TextureRect.new()
	logo.texture = load(ScreenLayout.LOGO_PATH)
	logo.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	logo.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	logo.position = Vector2(220, 30)
	logo.size = Vector2(200, 200)
	add_child(logo)

	var title_label := Label.new()
	title_label.text = "ORBIT ORANGE"
	title_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title_label.position = Vector2(0, 240)
	title_label.size = Vector2(ScreenLayout.SCREEN_SIZE.x, 30)
	add_child(title_label)

	var start_button := Button.new()
	start_button.text = "Start new game"
	start_button.position = Vector2(245, 290)
	start_button.size = Vector2(150, 36)
	start_button.pressed.connect(_on_start_new_game_pressed)
	add_child(start_button)


func _on_start_new_game_pressed() -> void:
	GameState.start_new_game()
	GameState.go_to_scene(GameState.MISSION_SELECT_SCENE_PATH)
