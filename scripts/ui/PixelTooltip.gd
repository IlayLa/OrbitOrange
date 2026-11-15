class_name PixelTooltip
extends RefCounted
## A hover tooltip that stays a readable block instead of one long line:
## the text is word-wrapped to at most MAXIMUM_WIDTH_PIXELS in the pixel
## font, so a card's tooltip is about as wide as the card itself.
## Return make(for_text) from a Control's _make_custom_tooltip. The panel
## around it is the theme's TooltipPanel (assets/ui/ui_theme.tres).
##
## The lines are wrapped here, not by Label autowrap: an autowrapped Label
## reports a one-line minimum height before it has a width, and the tooltip
## panel is sized from that minimum, so the text would spill out of it.

const MAXIMUM_WIDTH_PIXELS := 180.0
## No line limit: the tooltip is where the whole text is shown.
const UNLIMITED_LINE_COUNT := 1000


## A Label holding text wrapped to maximum_width_pixels, or null for empty
## text (Godot then shows no tooltip).
static func make(text: String, maximum_width_pixels: float = MAXIMUM_WIDTH_PIXELS) -> Label:
	if text.strip_edges().is_empty():
		return null
	var label := Label.new()
	label.text = "\n".join(wrapped_lines(text, maximum_width_pixels))
	label.add_theme_font_override("font", PixelGlyphs.font())
	label.add_theme_font_size_override("font_size", PixelGlyphs.TEXT_SIZE_PIXELS)
	label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	return label


## The text as lines no wider than maximum_width_pixels. Line breaks in the
## text are kept; each paragraph is wrapped between words.
static func wrapped_lines(text: String, maximum_width_pixels: float = MAXIMUM_WIDTH_PIXELS) -> Array[String]:
	var lines: Array[String] = []
	for paragraph in text.strip_edges().split("\n"):
		if paragraph.strip_edges().is_empty():
			lines.append("")
			continue
		lines.append_array(PixelGlyphs.wrap_lines(paragraph, maximum_width_pixels, UNLIMITED_LINE_COUNT))
	return lines
