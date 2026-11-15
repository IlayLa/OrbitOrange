class_name PixelTooltip
extends RefCounted
## A hover tooltip that stays a readable block instead of one long line:
## the text is word-wrapped in the pixel font to WRAP_WIDTH_PIXELS (or a
## wider width passed in, such as a card's), and nothing is ever cut.
## Return for_control(self, for_text) from a Control's _make_custom_tooltip,
## or call attach(control) on a Control that has no script of its own. The
## panel around it and the text colour are the theme's TooltipPanel and
## TooltipLabel (assets/ui/ui_theme.tres, or a screen's own theme).
##
## The lines are wrapped here, not by Label autowrap: an autowrapped Label
## reports a one-line minimum height before it has a width, and the tooltip
## panel is sized from that minimum, so the text would spill out of it.

const WRAP_WIDTH_PIXELS := 180.0
const TOOLTIP_LABEL_TYPE := "TooltipLabel"
const TOOLTIP_PANEL_TYPE := "TooltipPanel"
const HOST_SCRIPT := preload("res://scripts/ui/WrappedTooltipHost.gd")


## Gives a Control that has no script of its own the wrapped tooltip, by
## attaching WrappedTooltipHost. A Control with its own script should return
## for_control(self, for_text) from its _make_custom_tooltip instead.
static func attach(control: Control) -> void:
	if control.get_script() != null:
		push_error("PixelTooltip.attach: %s already has a script; return PixelTooltip.for_control from its _make_custom_tooltip" % control.name)
		return
	control.set_script(HOST_SCRIPT)


## The tooltip for a hovered control, in the TooltipLabel font size of the
## control's theme (the popup opens under the control, so a screen theme
## such as PlanningStyle applies). box_width_pixels, when given, is the
## outer width the tooltip may match, panel padding included (a card's width).
static func for_control(control: Control, text: String, box_width_pixels: float = 0.0) -> Label:
	var font_size: int = control.get_theme_font_size("font_size", TOOLTIP_LABEL_TYPE)
	var wrap_width_pixels := WRAP_WIDTH_PIXELS
	if box_width_pixels > 0.0:
		var panel: StyleBox = control.get_theme_stylebox("panel", TOOLTIP_PANEL_TYPE)
		var panel_width: float = panel.get_minimum_size().x if panel != null else 0.0
		wrap_width_pixels = maxf(WRAP_WIDTH_PIXELS, box_width_pixels - panel_width)
	return make(text, wrap_width_pixels, font_size)


## A Label holding text wrapped to wrap_width_pixels at font_size_pixels, or
## null for empty text (Godot then shows its default tooltip, which for empty
## text is none).
static func make(text: String, wrap_width_pixels: float = WRAP_WIDTH_PIXELS,
		font_size_pixels: int = PixelGlyphs.TEXT_SIZE_PIXELS) -> Label:
	if text.strip_edges().is_empty():
		return null
	var label := Label.new()
	label.theme_type_variation = TOOLTIP_LABEL_TYPE
	label.text = "\n".join(wrapped_lines(text, wrap_width_pixels, font_size_pixels))
	# The font and size are fixed, not left to the theme lookup inside the
	# popup: the lines were measured with exactly these.
	label.add_theme_font_override("font", PixelGlyphs.font())
	label.add_theme_font_size_override("font_size", font_size_pixels)
	return label


## The text as lines no wider than wrap_width_pixels. Line breaks in the text
## are kept (\r\n counts as one); tabs count as spaces. Each paragraph is
## wrapped between words, and a word wider than the line is broken between
## characters instead of being cut.
static func wrapped_lines(text: String, wrap_width_pixels: float = WRAP_WIDTH_PIXELS,
		font_size_pixels: int = PixelGlyphs.TEXT_SIZE_PIXELS) -> Array[String]:
	var lines: Array[String] = []
	var normalized_text := text.replace("\r\n", "\n").replace("\r", "\n").replace("\t", " ")
	for paragraph in normalized_text.strip_edges().split("\n"):
		var current_line := ""
		for word in paragraph.split(" ", false):
			var candidate: String = word if current_line.is_empty() else current_line + " " + word
			if PixelGlyphs.text_width(candidate, font_size_pixels) <= wrap_width_pixels:
				current_line = candidate
				continue
			if not current_line.is_empty():
				lines.append(current_line)
			var pieces: Array[String] = _broken_word(word, wrap_width_pixels, font_size_pixels)
			current_line = pieces.pop_back()
			lines.append_array(pieces)
		lines.append(current_line)
	return lines


## A word as pieces no wider than wrap_width_pixels (at least one character each).
static func _broken_word(word: String, wrap_width_pixels: float, font_size_pixels: int) -> Array[String]:
	var pieces: Array[String] = []
	var rest := word
	while rest.length() > 1 and PixelGlyphs.text_width(rest, font_size_pixels) > wrap_width_pixels:
		var kept_length := rest.length() - 1
		while kept_length > 1 and PixelGlyphs.text_width(rest.substr(0, kept_length), font_size_pixels) > wrap_width_pixels:
			kept_length -= 1
		pieces.append(rest.substr(0, kept_length))
		rest = rest.substr(kept_length)
	pieces.append(rest)
	return pieces
