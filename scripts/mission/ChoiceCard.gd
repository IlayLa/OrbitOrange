class_name ChoiceCard
extends CheckBox
## One choice on the mission screen (a mission, a science objective or a side
## quest) as a card: a check mark, a title, at most two lines of text cut with
## an ellipsis by the layout, then a row of glyph chips and, for science, the
## instrument-fit stars. A card that cannot be chosen is grey with a lock.
## The CheckBox text holds the title (for tests and screen readers) but is
## not drawn; the card face is drawn by _face.

const PADDING_PIXELS := 4.0
const MARKER_WIDTH_PIXELS := 12.0
const TITLE_ROW_HEIGHT_PIXELS := 12.0
const CHIP_ROW_HEIGHT_PIXELS := 11.0
const CHIP_GAP_PIXELS := 6.0
const MAXIMUM_BODY_LINE_COUNT := 2
const COLOR_CARD := Color("101820")
const COLOR_CARD_CHOSEN := Color("1b2c44")
const COLOR_FRAME := Color("83817c")
const COLOR_FRAME_HOVER := Color("bed3fa")

## True for a choice among several (round marker), false for a tick box.
var is_radio: bool = false
var is_locked: bool = false
## -1 hides the stars.
var fit_star_count: int = -1
var has_placeholder_badge: bool = false

var _title: String = ""
var _body_lines: Array[String] = []
## Each chip: "glyph", "text", "glyph_color", "text_color"; "position" is set by the layout.
var _chips: Array[Dictionary] = []
var _face: Control


## Fills the card. body_text is cut to two lines with an ellipsis; the whole
## text stays in the tooltip together with tooltip_extra.
func setup(title: String, body_text: String, chips: Array[Dictionary], card_width_pixels: float,
		tooltip_extra: String = "") -> void:
	_title = title
	text = title
	clip_text = true
	focus_mode = Control.FOCUS_ALL
	has_placeholder_badge = PixelGlyphs.is_placeholder_text(body_text)
	var shown_body := PixelGlyphs.without_placeholder_prefix(body_text)
	var text_width_pixels: float = card_width_pixels - 2.0 * PADDING_PIXELS - MARKER_WIDTH_PIXELS
	_body_lines = []
	if not shown_body.is_empty():
		_body_lines = PixelGlyphs.wrap_lines(shown_body, text_width_pixels, MAXIMUM_BODY_LINE_COUNT)
	_chips = chips
	tooltip_text = shown_body if tooltip_extra.is_empty() else (shown_body + "\n" + tooltip_extra).strip_edges()
	_apply_styles()

	var chip_left: float = PADDING_PIXELS + MARKER_WIDTH_PIXELS
	var next_top: float = PADDING_PIXELS + TITLE_ROW_HEIGHT_PIXELS + _body_lines.size() * PixelGlyphs.LINE_HEIGHT_PIXELS
	if not _chips.is_empty() or fit_star_count >= 0:
		next_top += 2.0
	var row_left: float = chip_left
	for chip in _chips:
		var chip_width: float = PixelGlyphs.chip_width(chip.get("glyph", ""), chip["text"])
		if row_left > chip_left and row_left + chip_width > card_width_pixels - PADDING_PIXELS:
			row_left = chip_left
			next_top += CHIP_ROW_HEIGHT_PIXELS
		chip["position"] = Vector2(row_left, next_top)
		row_left += chip_width + CHIP_GAP_PIXELS
	if not _chips.is_empty():
		next_top += CHIP_ROW_HEIGHT_PIXELS
	if fit_star_count >= 0:
		_chips.append({"glyph": "", "text": "", "position": Vector2(chip_left, next_top), "is_fit_row": true})
		next_top += CHIP_ROW_HEIGHT_PIXELS
	custom_minimum_size = Vector2(card_width_pixels, ceilf(next_top + PADDING_PIXELS - 1.0))

	if _face == null:
		_face = Control.new()
		_face.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_face.draw.connect(_draw_face)
		add_child(_face)
		toggled.connect(func(_is_pressed: bool) -> void: _face.queue_redraw())
		mouse_entered.connect(_face.queue_redraw)
		mouse_exited.connect(_face.queue_redraw)
	_face.size = custom_minimum_size
	_face.queue_redraw()


## Sets the chosen state without the toggled signal, and redraws the mark.
func set_chosen_quietly(is_chosen: bool) -> void:
	set_pressed_no_signal(is_chosen)
	if _face != null:
		_face.queue_redraw()


## Greys the card out and shows a lock. A locked card cannot be chosen.
func set_locked(new_is_locked: bool) -> void:
	is_locked = new_is_locked
	disabled = new_is_locked
	if _face != null:
		_face.queue_redraw()


func _apply_styles() -> void:
	var empty_icon := ImageTexture.create_from_image(Image.create(1, 1, false, Image.FORMAT_RGBA8))
	for icon_name in ["checked", "unchecked", "radio_checked", "radio_unchecked", "checked_disabled",
			"unchecked_disabled", "radio_checked_disabled", "radio_unchecked_disabled"]:
		add_theme_icon_override(icon_name, empty_icon)
	for color_name in ["font_color", "font_pressed_color", "font_hover_color", "font_hover_pressed_color",
			"font_focus_color", "font_disabled_color"]:
		add_theme_color_override(color_name, Color(0, 0, 0, 0))
	for style_name in ["normal", "hover", "pressed", "hover_pressed", "disabled", "focus"]:
		var style := StyleBoxFlat.new()
		style.bg_color = COLOR_CARD
		style.border_color = COLOR_FRAME
		style.set_border_width_all(1)
		match style_name:
			"hover":
				style.border_color = COLOR_FRAME_HOVER
			"pressed", "hover_pressed":
				style.bg_color = COLOR_CARD_CHOSEN
				style.border_color = ScreenLayout.COLOR_ACCENT_ORANGE
				style.set_border_width_all(2)
			"disabled":
				style.bg_color = ScreenLayout.COLOR_SPACE_BLACK
				style.border_color = PixelGlyphs.COLOR_DISABLED
			"focus":
				style.draw_center = false
				style.border_color = COLOR_FRAME_HOVER
		add_theme_stylebox_override(style_name, style)


func _draw_face() -> void:
	var text_color: Color = PixelGlyphs.COLOR_DISABLED if is_locked else ScreenLayout.COLOR_TEXT_LIGHT
	var muted_color: Color = PixelGlyphs.COLOR_DISABLED if is_locked else PixelGlyphs.COLOR_MUTED_TEXT
	_draw_marker(Vector2(PADDING_PIXELS, PADDING_PIXELS + 2.0))
	var text_left: float = PADDING_PIXELS + MARKER_WIDTH_PIXELS
	var title_width: float = size.x - text_left - PADDING_PIXELS - (12.0 if is_locked else 0.0)
	if has_placeholder_badge:
		title_width -= PixelGlyphs.text_width("PLACEHOLDER") + 8.0
	PixelGlyphs.draw_text(_face, Vector2(text_left, PADDING_PIXELS - 1.0), _title, text_color, PixelGlyphs.TITLE_SIZE_PIXELS, title_width)
	if has_placeholder_badge:
		PixelGlyphs.draw_placeholder_badge(_face, Vector2(size.x - PADDING_PIXELS - PixelGlyphs.text_width("PLACEHOLDER") - 4.0 - (12.0 if is_locked else 0.0), PADDING_PIXELS + 1.0))
	if is_locked:
		PixelGlyphs.draw_glyph(_face, "lock", Vector2(size.x - PADDING_PIXELS - 8.0, PADDING_PIXELS + 1.0), PixelGlyphs.COLOR_MUTED_TEXT)
	for line_index in _body_lines.size():
		PixelGlyphs.draw_text(_face, Vector2(text_left, PADDING_PIXELS + TITLE_ROW_HEIGHT_PIXELS + line_index * PixelGlyphs.LINE_HEIGHT_PIXELS),
				_body_lines[line_index], muted_color)
	for chip in _chips:
		if chip.get("is_fit_row", false):
			PartDetailsPopup.draw_fit_stars(_face, chip["position"], fit_star_count, "best fit")
			continue
		var glyph_color: Color = PixelGlyphs.COLOR_DISABLED if is_locked else chip.get("glyph_color", COLOR_FRAME_HOVER)
		var chip_text_color: Color = PixelGlyphs.COLOR_DISABLED if is_locked else chip.get("text_color", ScreenLayout.COLOR_TEXT_LIGHT)
		PixelGlyphs.draw_chip(_face, chip["position"], chip.get("glyph", ""), chip["text"], glyph_color, chip_text_color)


## A round marker for one-of-several choices and a square one for tick boxes.
## Chosen: filled with a dot or a tick. Shape and fill both change, not only colour.
func _draw_marker(top_left: Vector2) -> void:
	var marker_color: Color = PixelGlyphs.COLOR_DISABLED if is_locked else COLOR_FRAME_HOVER
	var marker_rect := Rect2(top_left.round(), Vector2(8, 8))
	if is_radio:
		_face.draw_arc(marker_rect.get_center(), 3.5, 0.0, TAU, 16, marker_color, 1.0)
		if button_pressed:
			_face.draw_rect(Rect2(marker_rect.position + Vector2(2, 2), Vector2(4, 4)), ScreenLayout.COLOR_ACCENT_ORANGE)
	else:
		_face.draw_rect(marker_rect.grow(-0.5), marker_color, false, 1.0)
		if button_pressed:
			PixelGlyphs.draw_glyph(_face, "check", marker_rect.position + Vector2(1, 0), ScreenLayout.COLOR_ACCENT_ORANGE)
