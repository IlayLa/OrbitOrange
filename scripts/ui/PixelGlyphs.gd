class_name PixelGlyphs
extends RefCounted
## Small pixel glyphs drawn in code, and the text helpers every redesigned
## screen shares (design/minimize_text_walls_options.md, "Shared rules"):
##   - every glyph is 7 x 7 pixels on the integer grid, with a 1 pixel dark
##     outline, so it reads on any background at 1x;
##   - glyphs differ by shape, never by colour alone;
##   - nothing is drawn smaller than 8 pixels (TEXT_SIZE_PIXELS).
## Static functions only. Draw from inside a CanvasItem's _draw (or its draw
## signal) by passing that CanvasItem as canvas.

const GLYPH_SIZE_PIXELS := 7
## Width a glyph takes in a row of chips, outline included, plus one gap pixel.
const GLYPH_ADVANCE_PIXELS := 10.0
const TEXT_SIZE_PIXELS := 8
const TITLE_SIZE_PIXELS := 10
const LINE_HEIGHT_PIXELS := 9.0
const ELLIPSIS := "…"

## The one colour added to ScreenLayout's palette: amber, for warnings.
const COLOR_AMBER := Color("ffb000")
## Green for "OK" and for a better value. ScreenLayout's land green, lightened
## so that it stays readable on the black monitors.
const COLOR_GOOD_GREEN := Color("5cc23c")
const COLOR_OUTLINE := Color("10141c")
const COLOR_MUTED_TEXT := Color("9fb0c8")
const COLOR_DISABLED := Color("6b7280")

## Every glyph as seven rows of seven characters: "#" is filled, "." is empty.
const PATTERNS := {
	# Warning lamps: the shape carries the meaning, the colour repeats it.
	"lamp_blocking": ["##...##", "###.###", ".#####.", "..###..", ".#####.", "###.###", "##...##"],
	"lamp_warning": ["...#...", "..###..", "..###..", ".#####.", ".#####.", "#######", "#######"],
	"lamp_ok": ["..###..", ".#####.", "#######", "#######", "#######", ".#####.", "..###.."],
	# Ratings and states.
	"star": ["...#...", "...#...", "#######", ".#####.", "..###..", ".##.##.", "##...##"],
	"lock": ["..###..", ".#...#.", ".#...#.", "#######", "###.###", "###.###", "#######"],
	"arrow_up": ["...#...", "..###..", ".#####.", "#######", "..###..", "..###..", "..###.."],
	"arrow_down": ["..###..", "..###..", "..###..", "#######", ".#####.", "..###..", "...#..."],
	"plus": ["...#...", "...#...", "...#...", "#######", "...#...", "...#...", "...#..."],
	"minus": [".......", ".......", ".......", "#######", ".......", ".......", "......."],
	"info": ["...#...", ".......", "..##...", "...#...", "...#...", "...#...", "..###.."],
	"question": [".#####.", "##...##", ".....##", "...###.", "...#...", ".......", "...#..."],
	"check": [".......", "......#", ".....##", "#...##.", "##.##..", ".###...", "..#...."],
	# Mission and money.
	"money": ["...#...", ".#####.", "##.#...", ".#####.", "...#.##", ".#####.", "...#..."],
	"clock": [".#####.", "#..#..#", "#..#..#", "#..##.#", "#.....#", "#.....#", ".#####."],
	"target": [".#####.", "#.....#", "#.###.#", "#.#.#.#", "#.###.#", "#.....#", ".#####."],
	"ellipse": [".......", ".#####.", "#.....#", "#.....#", "#.....#", ".#####.", "......."],
	"band": [".......", "#######", ".......", "#######", ".......", "#######", "......."],
	"hazard": ["#.#.#.#", ".#.#.#.", "#.#.#.#", ".#.#.#.", "#.#.#.#", ".#.#.#.", "#.#.#.#"],
	"risk": ["...#...", "..#.#..", ".#.#.#.", "#..#..#", ".#...#.", "..#.#..", "...#..."],
	# Two bars with arrows between them: the gap between achieved and target.
	"gap": ["#######", "...#...", "..###..", ".......", "..###..", "...#...", "#######"],
	"coverage": ["..###..", ".#..##.", "#...###", "#..####", "#.....#", ".#...#.", "..###.."],
	"data": [".#####.", "#.....#", ".#####.", "#.....#", ".#####.", "#.....#", ".#####."],
	# Part stats.
	"efficiency": ["....##.", "...##..", "..##...", ".#####.", "...##..", "..##...", ".##...."],
	"thrust": ["...#...", "..#.#..", ".#...#.", "...#...", "..#.#..", ".#...#.", "#.....#"],
	"fuel": ["...#...", "...#...", "..###..", ".#####.", ".#####.", ".#####.", "..###.."],
	"mass": ["..###..", "..#.#..", "..###..", ".#####.", ".#####.", "#######", "#######"],
	"range": ["####...", "....#..", "###..#.", "...#..#", "##..#.#", "..#.#.#", "#.#.#.#"],
	"rate": ["......#", "......#", "....#.#", "....#.#", "..#.#.#", "..#.#.#", "#.#.#.#"],
	"noise": [".......", ".......", ".#...#.", "#.#.#.#", "...#...", ".......", "......."],
	"resolution": [".......", "..###..", ".#...#.", "#..#..#", ".#...#.", "..###..", "......."],
	"dropout": ["##.....", "#.#....", ".#.#...", ".......", "...#.#.", "....#.#", ".....##"],
	"power": [".#...#.", ".#...#.", "#######", "#######", ".#####.", "..###..", "...#..."],
	"science": ["..###..", "...#...", "...#...", "..#.#..", ".#...#.", "#.###.#", "#######"],
	"pressure": [".#####.", "#.....#", "#....##", "#...#.#", "#..#..#", "#.....#", ".#####."],
	"channel": [".......", "#.....#", "#.#.#.#", "#.#.#.#", "#.#.#.#", "#.....#", "......."],
}

## name -> [filled cells, outline cells], each a PackedVector2Array of pixels.
static var _cell_cache: Dictionary = {}


## True when a glyph of this name exists.
static func has_glyph(glyph_name: String) -> bool:
	return PATTERNS.has(glyph_name)


## Draws one glyph with its top-left filled pixel area at top_left (the dark
## outline reaches one pixel further). top_left is rounded to whole pixels.
static func draw_glyph(canvas: CanvasItem, glyph_name: String, top_left: Vector2, fill_color: Color,
		has_outline: bool = true) -> void:
	if not PATTERNS.has(glyph_name):
		return
	var cells: Array = _cells_of(glyph_name)
	var origin := top_left.round()
	if has_outline:
		for outline_cell: Vector2 in cells[1]:
			canvas.draw_rect(Rect2(origin + outline_cell, Vector2.ONE), COLOR_OUTLINE)
	for filled_cell: Vector2 in cells[0]:
		canvas.draw_rect(Rect2(origin + filled_cell, Vector2.ONE), fill_color)


## The glyph and colour of a warning lamp for a WarningLamps severity.
static func lamp_glyph_name(severity: int) -> String:
	match severity:
		WarningLamps.Severity.BLOCKING:
			return "lamp_blocking"
		WarningLamps.Severity.WARNING:
			return "lamp_warning"
	return "lamp_ok"


static func lamp_color(severity: int) -> Color:
	match severity:
		WarningLamps.Severity.BLOCKING:
			return ScreenLayout.COLOR_WARNING_RED
		WarningLamps.Severity.WARNING:
			return COLOR_AMBER
	return COLOR_GOOD_GREEN


## The shared small font.
static func font() -> Font:
	return ThemeDB.fallback_font


## Width in pixels of text at the given font size.
static func text_width(text: String, font_size_pixels: int = TEXT_SIZE_PIXELS) -> float:
	return font().get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_pixels).x


## Draws one line of text whose top edge is at top_left.y. Text wider than
## maximum_width_pixels (when positive) is cut with an ellipsis.
static func draw_text(canvas: CanvasItem, top_left: Vector2, text: String, text_color: Color,
		font_size_pixels: int = TEXT_SIZE_PIXELS, maximum_width_pixels: float = -1.0) -> float:
	var shown_text := text
	if maximum_width_pixels > 0.0:
		shown_text = fit_to_width(text, maximum_width_pixels, font_size_pixels)
	var baseline := Vector2(roundf(top_left.x), roundf(top_left.y + font().get_ascent(font_size_pixels)))
	canvas.draw_string(font(), baseline, shown_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size_pixels, text_color)
	return text_width(shown_text, font_size_pixels)


## Draws a glyph followed by its text, both on one 9 pixel row whose top edge
## is top_left.y. Returns the width taken. Text never stands without its unit
## and a glyph never stands without its number: pass both.
static func draw_chip(canvas: CanvasItem, top_left: Vector2, glyph_name: String, text: String,
		glyph_color: Color, text_color: Color = ScreenLayout.COLOR_TEXT_LIGHT) -> float:
	var used_width := 0.0
	if not glyph_name.is_empty():
		draw_glyph(canvas, glyph_name, top_left + Vector2(1, 1), glyph_color)
		used_width = GLYPH_ADVANCE_PIXELS
	used_width += draw_text(canvas, top_left + Vector2(used_width, 0), text, text_color)
	return used_width


## The width draw_chip would take.
static func chip_width(glyph_name: String, text: String) -> float:
	return (0.0 if glyph_name.is_empty() else GLYPH_ADVANCE_PIXELS) + text_width(text)


## The text cut to fit one line of the given width, ending in an ellipsis
## when anything was cut.
static func fit_to_width(text: String, maximum_width_pixels: float, font_size_pixels: int = TEXT_SIZE_PIXELS) -> String:
	if text_width(text, font_size_pixels) <= maximum_width_pixels:
		return text
	var kept_length := text.length()
	while kept_length > 0 and text_width(text.substr(0, kept_length).strip_edges() + ELLIPSIS, font_size_pixels) > maximum_width_pixels:
		kept_length -= 1
	return text.substr(0, kept_length).strip_edges() + ELLIPSIS


## Word-wraps text into at most maximum_line_count lines of the given width.
## When the text does not fit, the last line ends in an ellipsis: the layout,
## not the data, decides how much is shown.
static func wrap_lines(text: String, maximum_width_pixels: float, maximum_line_count: int,
		font_size_pixels: int = TEXT_SIZE_PIXELS) -> Array[String]:
	var lines: Array[String] = []
	var words: PackedStringArray = text.strip_edges().split(" ", false)
	var current_line := ""
	var word_index := 0
	while word_index < words.size():
		var candidate := words[word_index] if current_line.is_empty() else current_line + " " + words[word_index]
		if text_width(candidate, font_size_pixels) <= maximum_width_pixels or current_line.is_empty():
			current_line = candidate
			word_index += 1
			continue
		if lines.size() == maximum_line_count - 1:
			break
		# A single word wider than the line is cut too.
		lines.append(fit_to_width(current_line, maximum_width_pixels, font_size_pixels))
		current_line = ""
	if not current_line.is_empty():
		var has_more_words := word_index < words.size()
		if has_more_words:
			current_line = fit_to_width(current_line + " " + " ".join(words.slice(word_index)), maximum_width_pixels, font_size_pixels)
		else:
			current_line = fit_to_width(current_line, maximum_width_pixels, font_size_pixels)
		lines.append(current_line)
	return lines


## Removes a leading "Placeholder:" or "Placeholder mission:" from catalogue
## text. The screens show a grey PLACEHOLDER badge instead.
static func without_placeholder_prefix(text: String) -> String:
	for prefix in ["Placeholder mission:", "Placeholder:"]:
		if text.begins_with(prefix):
			return text.trim_prefix(prefix).strip_edges()
	return text


static func is_placeholder_text(text: String) -> bool:
	return text.begins_with("Placeholder")


## Draws the grey 8 pixel PLACEHOLDER badge and returns its width.
static func draw_placeholder_badge(canvas: CanvasItem, top_left: Vector2) -> float:
	var badge_text := "PLACEHOLDER"
	var badge_width: float = placeholder_badge_width()
	canvas.draw_rect(Rect2(top_left.round(), Vector2(badge_width, 9)), COLOR_DISABLED)
	draw_text(canvas, top_left + Vector2(2, 0), badge_text, COLOR_OUTLINE)
	return badge_width


## The width draw_placeholder_badge takes.
static func placeholder_badge_width() -> float:
	return text_width("PLACEHOLDER") + 4.0


static func _cells_of(glyph_name: String) -> Array:
	if _cell_cache.has(glyph_name):
		return _cell_cache[glyph_name]
	var rows: Array = PATTERNS[glyph_name]
	var filled_cells := PackedVector2Array()
	var filled_lookup: Dictionary = {}
	for row_index in rows.size():
		var row: String = rows[row_index]
		for column_index in row.length():
			if row[column_index] == "#":
				filled_cells.append(Vector2(column_index, row_index))
				filled_lookup[Vector2i(column_index, row_index)] = true
	var outline_lookup: Dictionary = {}
	for filled_cell: Vector2 in filled_cells:
		for offset_y in [-1, 0, 1]:
			for offset_x in [-1, 0, 1]:
				var neighbour := Vector2i(int(filled_cell.x) + offset_x, int(filled_cell.y) + offset_y)
				if not filled_lookup.has(neighbour):
					outline_lookup[neighbour] = true
	var outline_cells := PackedVector2Array()
	for outline_cell: Vector2i in outline_lookup:
		outline_cells.append(Vector2(outline_cell))
	_cell_cache[glyph_name] = [filled_cells, outline_cells]
	return _cell_cache[glyph_name]
