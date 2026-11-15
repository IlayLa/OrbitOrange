extends Control
## The rocket design screen: the rocket preview on the left, the part cards
## and the four category tabs on the right.
## Requirements: context/plan_draft.md, sections "Zoom LEFT: Rocket build" and
## "Rocket design". Layout: the ROCKET_DESIGN_ rectangles in ScreenLayout.
##
## How it works:
##   - A click on a card changes GameState.design and calls
##     GameState.notify_design_changed().
##   - A click on an installed part in the preview removes it.
##   - Everything is redrawn from GameState when derived_changed arrives.
## This screen computes no mass, cost or delta-v itself.

const CATEGORIES: Array[String] = [
	GameData.CATEGORY_ENGINE,
	GameData.CATEGORY_TANK,
	GameData.CATEGORY_TELEMETRY,
	GameData.CATEGORY_SCIENCE,
]
## Names of the tabs as the mock-up writes them, in the order of CATEGORIES.
const TAB_NAMES: Array[String] = ["ENG", "MAT", "TEL", "SCI"]
const TAB_TOOLTIPS: Array[String] = [
	"Engines: each one starts a new stage",
	"Tanks (materials): feed a liquid engine",
	"Telemetry: sensors carried as payload",
	"Science: instruments carried as payload",
]
const SCROLL_BAR_WIDTH_PIXELS := 8.0
## Limits of the design. They are game values, chosen so that every block of
## the stack preview stays high enough to read and to click.
const MAXIMUM_STAGE_COUNT := 5
const MAXIMUM_PAYLOAD_PART_COUNT := 10
const HINT_FONT_SIZE_PIXELS := 8
const POPUP_GAP_PIXELS := 4.0

const HINT_DEFAULT := "Click a card to add the part.\nClick a part in the rocket to remove it."
const HINT_NO_LIQUID_STAGE := "A tank needs a liquid engine.\nAdd a liquid engine under ENG first."
const HINT_NO_MISSION := "No mission selected."
const HINT_TOO_MANY_STAGES := "The rocket is full: %d stages at most.\nRemove a stage first."
const HINT_TOO_MANY_PAYLOAD_PARTS := "The payload is full: %d parts at most.\nRemove a part first."
const HINT_LAUNCHED := "The rocket has launched.\nIts design can no longer change."

## The category whose cards are listed now.
var shown_category: String = GameData.CATEGORY_ENGINE
## The liquid stage that receives the next tank. 0 when none is selected.
var selected_stage_id: int = 0
var stack_preview: RocketStackPreview

var _tab_buttons: Array[Button] = []
var _card_list: VBoxContainer
var _card_scroll: ScrollContainer
var _hint_label: Label
var _details_popup: PartDetailsPopup
var _hint_text: String = HINT_DEFAULT


func _ready() -> void:
	# The layout is fixed to the mock-up, so it must not mirror itself on a
	# computer whose language is written right to left.
	layout_direction = Control.LAYOUT_DIRECTION_LTR
	size = ScreenLayout.SCREEN_SIZE
	var background := TextureRect.new()
	background.texture = load(ScreenLayout.ROCKET_DESIGN_BACKGROUND_PATH)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.size = ScreenLayout.SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(background)

	stack_preview = RocketStackPreview.new()
	stack_preview.is_interactive = true
	stack_preview.position = ScreenLayout.ROCKET_DESIGN_PREVIEW_SCREEN.position
	stack_preview.size = ScreenLayout.ROCKET_DESIGN_PREVIEW_SCREEN.size
	stack_preview.engine_clicked.connect(remove_stage)
	stack_preview.tank_clicked.connect(remove_tank)
	stack_preview.payload_clicked.connect(remove_payload_part)
	stack_preview.stage_tag_clicked.connect(select_stage)
	add_child(stack_preview)

	_create_card_list()
	_create_tabs()
	_create_hint()

	_details_popup = PartDetailsPopup.new()
	add_child(_details_popup)

	GameState.derived_changed.connect(_refresh)
	GameState.launch_requested.connect(_on_launch_requested)
	show_category(shown_category)
	_refresh()


## Lists the cards of one category ("engine", "tank", "telemetry" or "science").
func show_category(category: String) -> void:
	shown_category = category
	for tab_index in _tab_buttons.size():
		_tab_buttons[tab_index].set_pressed_no_signal(CATEGORIES[tab_index] == category)

	_details_popup.hide()
	for existing_card in _card_list.get_children():
		_card_list.remove_child(existing_card)
		existing_card.queue_free()

	var card_width_pixels: float = ScreenLayout.ROCKET_DESIGN_PART_LIST.size.x - SCROLL_BAR_WIDTH_PIXELS
	for part in GameData.parts_in_category(category):
		var card := PartCard.new()
		card.configure(part, card_width_pixels)
		card.card_pressed.connect(install_part)
		card.card_hovered.connect(_on_card_hovered.bind(card))
		card.card_unhovered.connect(_on_card_unhovered)
		_card_list.add_child(card)
	_card_scroll.scroll_vertical = 0


## The card of the part in the list shown now, or null.
func find_part_card(part_id: String) -> PartCard:
	for card: PartCard in _card_list.get_children():
		if card.part_id == part_id:
			return card
	return null


## Adds the part to GameState.design, by its category:
##   engine               a new stage on top of the stack
##   tank                 the tank of the selected liquid stage; see
##                        _stage_for_new_tank for the choice without a selection
##   telemetry, science   one more payload part
## Does nothing once the rocket has launched, or when the rocket already has
## MAXIMUM_STAGE_COUNT stages or MAXIMUM_PAYLOAD_PART_COUNT payload parts.
func install_part(part_id: String) -> void:
	if _is_design_locked():
		return
	var part: Dictionary = GameData.part(part_id)
	if part.is_empty():
		return
	var design: RocketDesign = GameState.design
	_hint_text = HINT_DEFAULT

	match part.get("category", ""):
		GameData.CATEGORY_ENGINE:
			if design.stages.size() >= MAXIMUM_STAGE_COUNT:
				_hint_text = HINT_TOO_MANY_STAGES % MAXIMUM_STAGE_COUNT
				_refresh()
				return
			var new_stage: Stage = design.add_stage(part_id)
			if not RocketStackPreview.is_solid_engine(part_id):
				selected_stage_id = new_stage.stage_id
		GameData.CATEGORY_TANK:
			var stage_for_tank: Stage = _stage_for_new_tank()
			if stage_for_tank == null:
				_hint_text = HINT_NO_LIQUID_STAGE
				_refresh()
				return
			stage_for_tank.tank_part_id = part_id
			selected_stage_id = stage_for_tank.stage_id
		GameData.CATEGORY_TELEMETRY, GameData.CATEGORY_SCIENCE:
			if design.payload_part_ids.size() >= MAXIMUM_PAYLOAD_PART_COUNT:
				_hint_text = HINT_TOO_MANY_PAYLOAD_PARTS % MAXIMUM_PAYLOAD_PART_COUNT
				_refresh()
				return
			design.payload_part_ids.append(part_id)
		_:
			return

	_notify_design_changed()


## Removes the stage from the design, and also from the plan: its id leaves
## the launch stages, and every pulse that fires it is deleted.
func remove_stage(stage_id: int) -> void:
	if _is_design_locked():
		return
	var design: RocketDesign = GameState.design
	if design.find_stage(stage_id) == null:
		return
	design.remove_stage(stage_id)

	var plan: MissionPlan = GameState.plan
	# erase removes one entry only, so repeat it in case the id is listed twice.
	while plan.launch_stage_ids.has(stage_id):
		plan.launch_stage_ids.erase(stage_id)
	var kept_pulses: Array[Pulse] = []
	for pulse in plan.pulses:
		if pulse.stage_id != stage_id:
			kept_pulses.append(pulse)
	plan.pulses = kept_pulses

	if selected_stage_id == stage_id:
		selected_stage_id = 0
	_hint_text = HINT_DEFAULT
	GameState.notify_design_changed()
	GameState.notify_plan_changed()
	if GameState.mission.is_empty():
		_refresh()


## Takes the tank off a liquid stage. The stage and its engine stay.
func remove_tank(stage_id: int) -> void:
	if _is_design_locked():
		return
	var stage: Stage = GameState.design.find_stage(stage_id)
	if stage == null:
		return
	stage.tank_part_id = ""
	selected_stage_id = stage_id
	_hint_text = HINT_DEFAULT
	_notify_design_changed()


## Removes one payload part, by its index in RocketDesign.payload_part_ids.
func remove_payload_part(payload_index: int) -> void:
	if _is_design_locked():
		return
	var payload_part_ids: Array[String] = GameState.design.payload_part_ids
	if payload_index < 0 or payload_index >= payload_part_ids.size():
		return
	payload_part_ids.remove_at(payload_index)
	_hint_text = HINT_DEFAULT
	_notify_design_changed()


## Chooses the liquid stage that receives the next tank. Solid motors carry
## their own propellant, so they cannot be selected.
func select_stage(stage_id: int) -> void:
	var stage: Stage = GameState.design.find_stage(stage_id)
	if stage == null or RocketStackPreview.is_solid_engine(stage.engine_part_id):
		return
	selected_stage_id = stage_id
	_refresh()


## True once the player has launched: the rocket that flies, and the cost that
## is scored, must stay the one that was launched. Shows the reason as the hint.
func _is_design_locked() -> bool:
	if not GameState.has_launched:
		return false
	_hint_text = HINT_LAUNCHED
	_refresh()
	return true


func _notify_design_changed() -> void:
	GameState.notify_design_changed()
	# Without a mission GameState recomputes nothing and sends no signal.
	if GameState.mission.is_empty():
		_refresh()


## The stage that receives a new tank:
##   1. the selected liquid stage;
##   2. otherwise the highest liquid stage that has no tank yet;
##   3. otherwise the highest liquid stage, whose tank is then replaced.
## Null only when the rocket has no liquid stage at all.
func _stage_for_new_tank() -> Stage:
	var design: RocketDesign = GameState.design
	var selected_stage: Stage = design.find_stage(selected_stage_id)
	if selected_stage != null and not RocketStackPreview.is_solid_engine(selected_stage.engine_part_id):
		return selected_stage
	var highest_liquid_stage: Stage = null
	for stage_index in range(design.stages.size() - 1, -1, -1):
		var candidate_stage: Stage = design.stages[stage_index]
		if RocketStackPreview.is_solid_engine(candidate_stage.engine_part_id):
			continue
		if candidate_stage.tank_part_id.is_empty():
			return candidate_stage
		if highest_liquid_stage == null:
			highest_liquid_stage = candidate_stage
	return highest_liquid_stage


func _refresh() -> void:
	# The design may have been replaced from outside (for example by
	# "Build example rocket"), so the selection is checked every time.
	if GameState.design.find_stage(selected_stage_id) == null:
		selected_stage_id = 0
	stack_preview.show_design(GameState.design, selected_stage_id)

	var hint_lines: Array[String] = [_hint_text]
	if GameState.mission.is_empty():
		hint_lines.append(HINT_NO_MISSION)
	if selected_stage_id != 0:
		hint_lines.append("Next tank: stage %d (orange). Click S1, S2... to change." % _stage_number(selected_stage_id))
	_hint_label.text = "\n".join(PackedStringArray(hint_lines))


func _stage_number(stage_id: int) -> int:
	var stages: Array[Stage] = GameState.design.stages
	for stage_index in stages.size():
		if stages[stage_index].stage_id == stage_id:
			return stage_index + 1
	return 0


func _create_card_list() -> void:
	var list_rect: Rect2 = ScreenLayout.ROCKET_DESIGN_PART_LIST
	_card_scroll = ScrollContainer.new()
	_card_scroll.position = list_rect.position
	_card_scroll.size = list_rect.size
	_card_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	add_child(_card_scroll)

	_card_list = VBoxContainer.new()
	_card_list.add_theme_constant_override("separation", 2)
	_card_scroll.add_child(_card_list)


func _create_tabs() -> void:
	# The mock-up already writes ENG, MAT, TEL and SCI, so the buttons only add
	# a frame: orange for the chosen tab, light while the mouse is over one.
	var chosen_style := StyleBoxFlat.new()
	chosen_style.bg_color = Color(ScreenLayout.COLOR_ACCENT_ORANGE, 0.25)
	chosen_style.border_color = ScreenLayout.COLOR_ACCENT_ORANGE
	chosen_style.set_border_width_all(2)
	var hover_style := StyleBoxFlat.new()
	hover_style.bg_color = Color(ScreenLayout.COLOR_TEXT_LIGHT, 0.12)
	hover_style.border_color = ScreenLayout.COLOR_MONITOR_GRID_LINE
	hover_style.set_border_width_all(1)
	var empty_style := StyleBoxEmpty.new()

	for tab_index in CATEGORIES.size():
		var tab_rect: Rect2 = ScreenLayout.ROCKET_DESIGN_CATEGORY_TABS[tab_index]
		var tab_button := Button.new()
		tab_button.name = TAB_NAMES[tab_index]
		tab_button.position = tab_rect.position
		tab_button.size = tab_rect.size
		tab_button.toggle_mode = true
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.tooltip_text = TAB_TOOLTIPS[tab_index]
		tab_button.add_theme_stylebox_override("normal", empty_style)
		tab_button.add_theme_stylebox_override("hover", hover_style)
		tab_button.add_theme_stylebox_override("pressed", chosen_style)
		tab_button.add_theme_stylebox_override("hover_pressed", chosen_style)
		tab_button.pressed.connect(show_category.bind(CATEGORIES[tab_index]))
		add_child(tab_button)
		_tab_buttons.append(tab_button)


func _create_hint() -> void:
	var free_cell: Rect2 = ScreenLayout.ROCKET_DESIGN_FREE_CELL
	_hint_label = Label.new()
	_hint_label.position = free_cell.position + Vector2(3, 3)
	_hint_label.size = free_cell.size - Vector2(6, 6)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.clip_text = true
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_font_size_override("font_size", HINT_FONT_SIZE_PIXELS)
	_hint_label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	_hint_label.add_theme_constant_override("line_spacing", -1)
	add_child(_hint_label)


func _on_card_hovered(part_id: String, card: PartCard) -> void:
	# The popup opens to the left of the list, level with the card.
	var list_rect: Rect2 = ScreenLayout.ROCKET_DESIGN_PART_LIST
	var card_top_pixels: float = card.global_position.y - global_position.y
	var wanted_position := Vector2(
			list_rect.position.x - PartDetailsPopup.POPUP_WIDTH_PIXELS - POPUP_GAP_PIXELS,
			card_top_pixels)
	_details_popup.show_part(GameData.part(part_id), GameState.science_mission_id, wanted_position)


func _on_launch_requested() -> void:
	_hint_text = HINT_LAUNCHED
	_refresh()


func _on_card_unhovered() -> void:
	_details_popup.hide()
