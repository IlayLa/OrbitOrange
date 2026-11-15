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
##
## Text walls are kept off this screen (design/minimize_text_walls_options.md,
## Option 1): the part popup is an instrument panel with better/worse arrows
## against the part in the same slot, each stage carries a warning lamp, and
## the cell under the tabs holds a legend of the active category's glyphs. It
## collapses to "?" once the first part is installed. The cell also shows a
## short message when a click could not be done (_hint_label).

## Sent when the Data Sources codex opens or closes, so that PlanningConsole
## can hide the chrome it draws over this screen (the back button and the
## stat chips) while the codex is open.
signal data_sources_visibility_changed(is_open: bool)

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
## The tab names are drawn by the buttons, smaller than the mock-up's letters
## at five times scale, which dwarfed the rest of the screen. The pixel font
## is an 11 pixel face that scales by whole steps only, so 22 is twice its size.
const TAB_FONT_SIZE_PIXELS := 22
## Top-left corner of the part popup: against the right edge of the screen,
## over the category tabs, below the back button.
const POPUP_POSITION := Vector2(ScreenLayout.SCREEN_SIZE.x - PartDetailsPopup.POPUP_WIDTH_PIXELS - 2.0, 58.0)
const LEGEND_ROW_HEIGHT_PIXELS := 9.0
const LEGEND_TOGGLE_SIZE := Vector2(13, 13)
## Rectangle of the Data Sources codex panel: over the preview and the part
## list, clear of the stat chips above them.
const CODEX_PANEL_RECT := Rect2(60, 48, 520, 330)

## No message: the legend explains the screen.
const HINT_DEFAULT := ""
const HINT_NO_LIQUID_STAGE := "A tank needs a liquid engine. Add one under ENG."
const HINT_NO_MISSION := "No mission selected."
const HINT_TOO_MANY_STAGES := "Rocket full: %d stages at most."
const HINT_TOO_MANY_PAYLOAD_PARTS := "Payload full: %d parts at most."
const HINT_LAUNCHED := "The rocket has launched: the design is locked."

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
var _legend: Control
var _legend_toggle: Button
## True while the legend is open. It closes by itself once, when the first
## part is installed; "?" opens it again.
var is_legend_expanded: bool = true
var _has_legend_collapsed_once: bool = false
var _codex: DataSourcesCodex


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

	_codex = DataSourcesCodex.new(CODEX_PANEL_RECT)
	_codex.visibility_changed.connect(func() -> void: data_sources_visibility_changed.emit(_codex.visible))
	add_child(_codex)

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
		card.card_info_requested.connect(open_data_sources)
		_card_list.add_child(card)
	_card_scroll.scroll_vertical = 0
	if _legend != null:
		_legend.queue_redraw()


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


## Opens the Data Sources codex at this part's full citation.
func open_data_sources(part_id: String = "") -> void:
	_details_popup.hide()
	_codex.open_at(part_id)


## Opens or closes the legend of the glyphs.
func toggle_legend() -> void:
	is_legend_expanded = not is_legend_expanded
	_refresh_legend()


## The part already installed in the slot the hovered part would go to, to
## compare against: the selected stage's engine or tank for engines and tanks,
## the payload part reading the same channel for telemetry, the first science
## part of the payload for science. An empty Dictionary for an empty slot.
func installed_part_for_comparison(part: Dictionary) -> Dictionary:
	var design: RocketDesign = GameState.design
	match part.get("category", ""):
		GameData.CATEGORY_ENGINE, GameData.CATEGORY_TANK:
			var selected_stage: Stage = design.find_stage(selected_stage_id)
			if selected_stage == null:
				return {}
			var installed_part_id: String = selected_stage.engine_part_id
			if part.get("category", "") == GameData.CATEGORY_TANK:
				installed_part_id = selected_stage.tank_part_id
			return {} if installed_part_id.is_empty() else GameData.part(installed_part_id)
		GameData.CATEGORY_TELEMETRY:
			var channel: String = part.get("stats", {}).get("channel", "")
			for payload_part_id in design.payload_part_ids:
				var payload_part: Dictionary = GameData.part(payload_part_id)
				if payload_part.get("category", "") == GameData.CATEGORY_TELEMETRY and payload_part.get("stats", {}).get("channel", "") == channel:
					return payload_part
		GameData.CATEGORY_SCIENCE:
			for payload_part_id in design.payload_part_ids:
				var payload_part: Dictionary = GameData.part(payload_part_id)
				if payload_part.get("category", "") == GameData.CATEGORY_SCIENCE:
					return payload_part
	return {}


func _refresh() -> void:
	# The design may have been replaced from outside (for example by
	# "Build example rocket"), so the selection is checked every time.
	if GameState.design.find_stage(selected_stage_id) == null:
		selected_stage_id = 0
	stack_preview.show_design(GameState.design, selected_stage_id)
	stack_preview.show_lamps(WarningLamps.lamps_from_summary(GameState.summary))

	var hint_lines: Array[String] = []
	if not _hint_text.is_empty():
		hint_lines.append(_hint_text)
	if GameState.mission.is_empty():
		hint_lines.append(HINT_NO_MISSION)
	_hint_label.text = "\n".join(PackedStringArray(hint_lines))

	var has_any_part: bool = not GameState.design.stages.is_empty() or not GameState.design.payload_part_ids.is_empty()
	if has_any_part and not _has_legend_collapsed_once:
		_has_legend_collapsed_once = true
		is_legend_expanded = false
	_refresh_legend()


## The legend fills the cell under the tabs while it is open and there is no
## message; otherwise only the "?" button shows, beside the message.
func _refresh_legend() -> void:
	if _legend == null:
		return
	_legend.visible = is_legend_expanded and _hint_label.text.is_empty()
	_legend_toggle.text = "x" if _legend.visible else "?"
	_legend_toggle.tooltip_text = "Hide the legend" if _legend.visible else "Show the legend of the glyphs"
	_hint_label.visible = not _hint_label.text.is_empty()
	_legend.queue_redraw()


## Rows of the legend: one per stat glyph of the shown category, then the
## arrows (shape = the number went up or down against the installed part,
## colour = better or worse for you), the lamps and the source mark.
func _draw_legend() -> void:
	var legend_rows: Array[Array] = PartDetailsPopup.legend_entries(shown_category)
	legend_rows.append(["arrows_direction", "higher / lower"])
	legend_rows.append(["arrows_effect", "better / worse"])
	legend_rows.append(["lamp_warning", "lamp: hover / click"])
	legend_rows.append(["info", "right-click: source"])
	var maximum_row_count: int = floori(_legend.size.y / LEGEND_ROW_HEIGHT_PIXELS)
	for row_index in mini(legend_rows.size(), maximum_row_count):
		var row: Array = legend_rows[row_index]
		var row_top: float = row_index * LEGEND_ROW_HEIGHT_PIXELS
		var text_left: float = PixelGlyphs.GLYPH_ADVANCE_PIXELS
		match row[0]:
			"arrows_direction":
				PixelGlyphs.draw_glyph(_legend, "arrow_up", Vector2(1, row_top + 1.0), PartCard.COLOR_GLYPH)
				PixelGlyphs.draw_glyph(_legend, "arrow_down", Vector2(10, row_top + 1.0), PartCard.COLOR_GLYPH)
				text_left += 9.0
			"arrows_effect":
				PixelGlyphs.draw_glyph(_legend, "arrow_up", Vector2(1, row_top + 1.0), PartDetailsPopup.delta_arrow_color(1))
				PixelGlyphs.draw_glyph(_legend, "arrow_up", Vector2(10, row_top + 1.0), PartDetailsPopup.delta_arrow_color(-1))
				text_left += 9.0
			"lamp_warning":
				PixelGlyphs.draw_glyph(_legend, row[0], Vector2(1, row_top + 1.0), PixelGlyphs.COLOR_AMBER)
			_:
				PixelGlyphs.draw_glyph(_legend, row[0], Vector2(1, row_top + 1.0), PartCard.COLOR_GLYPH)
		var text_width: float = _legend.size.x - text_left
		if row_top + LEGEND_ROW_HEIGHT_PIXELS > _legend.size.y - LEGEND_TOGGLE_SIZE.y:
			# Keep clear of the toggle button in the bottom right corner.
			text_width -= LEGEND_TOGGLE_SIZE.x + 2.0
		PixelGlyphs.draw_text(_legend, Vector2(text_left, row_top), row[1],
				ScreenLayout.COLOR_TEXT_LIGHT, PixelGlyphs.TEXT_SIZE_PIXELS, text_width)


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
	# Each button covers its tile of the mock-up with the tile's own blue and
	# writes the name itself, at a size that sits with the rest of the screen.
	# The chosen tab is solid orange with black text; the mouse adds an orange
	# frame, like the button skin's hover state.
	var normal_style := _tab_style(ScreenLayout.COLOR_PANEL_DARK_BLUE, ScreenLayout.COLOR_PANEL_DARK_BLUE)
	var hover_style := _tab_style(ScreenLayout.COLOR_PANEL_DARK_BLUE, ScreenLayout.COLOR_ACCENT_ORANGE)
	var chosen_style := _tab_style(ScreenLayout.COLOR_ACCENT_ORANGE, ScreenLayout.COLOR_ACCENT_ORANGE)
	var chosen_hover_style := _tab_style(ScreenLayout.COLOR_ACCENT_ORANGE, ScreenLayout.COLOR_TEXT_LIGHT)

	for tab_index in CATEGORIES.size():
		var tab_rect: Rect2 = ScreenLayout.ROCKET_DESIGN_CATEGORY_TABS[tab_index]
		var tab_button := Button.new()
		tab_button.name = TAB_NAMES[tab_index]
		tab_button.text = TAB_NAMES[tab_index]
		tab_button.position = tab_rect.position
		tab_button.size = tab_rect.size
		tab_button.toggle_mode = true
		tab_button.focus_mode = Control.FOCUS_NONE
		tab_button.tooltip_text = TAB_TOOLTIPS[tab_index]
		tab_button.add_theme_font_size_override("font_size", TAB_FONT_SIZE_PIXELS)
		tab_button.add_theme_stylebox_override("normal", normal_style)
		tab_button.add_theme_stylebox_override("hover", hover_style)
		tab_button.add_theme_stylebox_override("pressed", chosen_style)
		tab_button.add_theme_stylebox_override("hover_pressed", chosen_hover_style)
		for color_name in ["font_color", "font_hover_color", "font_focus_color"]:
			tab_button.add_theme_color_override(color_name, ScreenLayout.COLOR_TEXT_LIGHT)
		for color_name in ["font_pressed_color", "font_hover_pressed_color"]:
			tab_button.add_theme_color_override(color_name, Color.BLACK)
		tab_button.pressed.connect(show_category.bind(CATEGORIES[tab_index]))
		add_child(tab_button)
		_tab_buttons.append(tab_button)


func _tab_style(fill_color: Color, border_color: Color) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill_color
	style.border_color = border_color
	style.set_border_width_all(2)
	return style


func _create_hint() -> void:
	var free_cell: Rect2 = ScreenLayout.ROCKET_DESIGN_FREE_CELL
	var cell_background := ColorRect.new()
	cell_background.color = Color(ScreenLayout.COLOR_SPACE_BLACK, 0.55)
	cell_background.position = free_cell.position + Vector2(2, 2)
	cell_background.size = free_cell.size - Vector2(4, 4)
	cell_background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(cell_background)

	_legend = Control.new()
	_legend.position = free_cell.position + Vector2(4, 4)
	_legend.size = free_cell.size - Vector2(8, 8)
	_legend.clip_contents = true
	_legend.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_legend.draw.connect(_draw_legend)
	add_child(_legend)

	_hint_label = Label.new()
	_hint_label.position = free_cell.position + Vector2(4, 4)
	_hint_label.size = free_cell.size - Vector2(8 + LEGEND_TOGGLE_SIZE.x, 8)
	_hint_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_hint_label.clip_text = true
	_hint_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_hint_label.add_theme_font_size_override("font_size", HINT_FONT_SIZE_PIXELS)
	_hint_label.add_theme_color_override("font_color", PixelGlyphs.COLOR_AMBER)
	_hint_label.add_theme_constant_override("line_spacing", -1)
	add_child(_hint_label)

	_legend_toggle = Button.new()
	_legend_toggle.text = "?"
	_legend_toggle.focus_mode = Control.FOCUS_NONE
	_legend_toggle.add_theme_font_size_override("font_size", HINT_FONT_SIZE_PIXELS)
	_legend_toggle.position = free_cell.end - LEGEND_TOGGLE_SIZE - Vector2(3, 3)
	_legend_toggle.pressed.connect(toggle_legend)
	add_child(_legend_toggle)
	_legend_toggle.size = LEGEND_TOGGLE_SIZE
	_legend_toggle.set_deferred("size", LEGEND_TOGGLE_SIZE)


func _on_card_hovered(part_id: String, _card: PartCard) -> void:
	# The popup is anchored over the tabs on the right, so that it covers
	# neither the rocket and its labels nor the card list.
	var part: Dictionary = GameData.part(part_id)
	_details_popup.show_part(part, GameState.science_mission_id, POPUP_POSITION, installed_part_for_comparison(part))


func _on_launch_requested() -> void:
	_hint_text = HINT_LAUNCHED
	_refresh()


func _on_card_unhovered() -> void:
	_details_popup.hide()
