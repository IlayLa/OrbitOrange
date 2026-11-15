class_name PixelTooltip
extends RefCounted
## A hover tooltip that stays a readable block instead of one long line:
## the text is word-wrapped in the pixel font to WRAP_WIDTH_PIXELS (or a
## wider width passed in, such as a card's), and nothing is ever cut.
## Return make(for_text) from a Control's _make_custom_tooltip. The panel
## around it and the text colour are the theme's TooltipPanel and
## TooltipLabel (assets/ui/ui_theme.tres).
##
## The lines are wrapped here, not by Label autowrap: an autowrapped Label
## reports a one-line minimum height before it has a width, and the tooltip
## panel is sized from that minimum, so the text would spill out of it.

const WRAP_WIDTH_PIXELS := 180.0
const HOST_SCRIPT_PATH := "res://scripts/ui/WrappedTooltipHost.gd"


## Gives a Control that has no script of its own the wrapped tooltip, by
## attaching WrappedTooltipHost. A Control with its own script should define
## _make_custom_tooltip and return make(for_text) itself instead.
static func attach(control: Control) -> void:
	if control.get_script() != null:
		push_error("PixelTooltip.attach: %s already has a script; return PixelTooltip.make from its _make_custom_tooltip" % control.name)
		return
	control.set_script(load(HOST_SCRIPT_PATH))


## A Label holding text wrapped to wrap_width_pixels, or null for empty text
## (Godot then shows its default tooltip, which for empty text is none).
static func make(text: String, wrap_width_pixels: float = WRAP_WIDTH_PIXELS) -> Label:
	if text.strip_edges().is_empty():
		return null
	var label := Label.new()
	label.theme_type_variation = "TooltipLabel"
	label.text = "\n".join(wrapped_lines(text, wrap_width_pixels))
	# The font and size are fixed, not left to the theme: the lines were
	# measured with them, and a screen theme (PlanningStyle) may set another
	# TooltipLabel size that would push the lines past the wrap width.
	label.add_theme_font_override("font", PixelGlyphs.font())
	label.add_theme_font_size_override("font_size", PixelGlyphs.TEXT_SIZE_PIXELS)
	return label


## The text as lines no wider than wrap_width_pixels. Line breaks in the text
## are kept; each paragraph is wrapped between words, and a word wider than
## the line is broken between characters instead of being cut.
static func wrapped_lines(text: String, wrap_width_pixels: float = WRAP_WIDTH_PIXELS) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in text.strip_edges().split("\n"):
		var current_line := ""
		for word in paragraph.split(" ", false):
			var candidate: String = word if current_line.is_empty() else current_line + " " + word
			if PixelGlyphs.text_width(candidate) <= wrap_width_pixels:
				current_line = candidate
				continue
			if not current_line.is_empty():
				lines.append(current_line)
			var pieces: Array[String] = _broken_word(word, wrap_width_pixels)
			current_line = pieces.pop_back()
			lines.append_array(pieces)
		lines.append(current_line)
	return lines


## A word as pieces no wider than wrap_width_pixels (at least one character each).
static func _broken_word(word: String, wrap_width_pixels: float) -> Array[String]:
	var pieces: Array[String] = []
	var rest := word
	while rest.length() > 1 and PixelGlyphs.text_width(rest) > wrap_width_pixels:
		var kept_length := rest.length() - 1
		while kept_length > 1 and PixelGlyphs.text_width(rest.substr(0, kept_length)) > wrap_width_pixels:
			kept_length -= 1
		pieces.append(rest.substr(0, kept_length))
		rest = rest.substr(kept_length)
	pieces.append(rest)
	return pieces
