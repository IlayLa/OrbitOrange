extends SceneTree
## Builds res://assets/ui/pixel_font.tres from the artist's glyph sheet
## res://design/template.png.
##
## The sheet is not a uniform grid: glyphs have different widths and the
## last row mixes sizes. GLYPH_ROWS below names, for each row of the sheet,
## the area it covers, the pixel row the glyphs stand on, and the characters
## in it from left to right. Inside that area every run of columns with ink
## is one glyph, so the artist can redraw a glyph or move it sideways without
## touching this file. Adding a character means drawing it on the sheet and
## adding it to the matching row string here.
##
## Rebuild after editing the sheet (Git Bash, from the project folder):
##     "$GODOT_EXECUTABLE" --headless --path . -s res://tools/build_pixel_font.gd

const SHEET_PATH := "res://design/template.png"
const FONT_PATH := "res://assets/ui/pixel_font.tres"

## Font size the glyphs are drawn at, 1:1 (caps are 7 px tall). Godot scales
## a fixed-size font by the rounded ratio of the asked size to this one, so
## with 11 every size up to 16 (the default) draws 1:1 and 17-27 draws at 2x;
## the pixels stay square either way.
const FIXED_SIZE := 11
const ASCENT := 8
const DESCENT := 2
const LETTER_SPACING := 1
const SPACE_ADVANCE := 3

## area: the part of the sheet holding this row of glyphs.
## baseline: the last pixel row of a letter without a descender.
## breaks (optional): x of the first column of a glyph that touches the
## glyph to its left with no empty column between them.
const GLYPH_ROWS := [
	{"area": Rect2i(0, 1, 64, 9), "baseline": 8, "characters": "1234567890"},
	{"area": Rect2i(0, 10, 64, 8), "baseline": 17, "characters": "ABCDEFGHIJK"},
	{"area": Rect2i(0, 18, 64, 8), "baseline": 25, "characters": "LMNOPQRSTUV"},
	{"area": Rect2i(0, 26, 64, 8), "baseline": 33, "characters": "WXYZ"},
	{"area": Rect2i(0, 34, 64, 8), "baseline": 41, "characters": "abcdefghijklm"},
	{"area": Rect2i(0, 42, 64, 8), "baseline": 49, "characters": "nopqrstuvwxy"},
	{"area": Rect2i(0, 50, 8, 6), "baseline": 55, "characters": "z"},
	{"area": Rect2i(8, 54, 56, 10), "baseline": 62, "characters": "θϒΔ$", "breaks": [23]},
]


func _init() -> void:
	var sheet := Image.load_from_file(ProjectSettings.globalize_path(SHEET_PATH))
	if sheet == null:
		push_error("Could not load %s" % SHEET_PATH)
		quit(1)
		return
	sheet.convert(Image.FORMAT_RGBA8)

	var font := FontFile.new()
	font.fixed_size = FIXED_SIZE
	font.fixed_size_scale_mode = TextServer.FIXED_SIZE_SCALE_INTEGER_ONLY
	font.antialiasing = TextServer.FONT_ANTIALIASING_NONE
	font.hinting = TextServer.HINTING_NONE
	font.subpixel_positioning = TextServer.SUBPIXEL_POSITIONING_DISABLED
	font.font_name = "OrbitOrange Pixel"

	var cache_size := Vector2i(FIXED_SIZE, 0)
	font.set_cache_ascent(0, FIXED_SIZE, ASCENT)
	font.set_cache_descent(0, FIXED_SIZE, DESCENT)
	font.set_texture_image(0, cache_size, 0, _white_glyphs(sheet))

	_add_glyph(font, cache_size, " ".unicode_at(0), Rect2i(), 0, SPACE_ADVANCE)
	var glyph_count := 0
	for glyph_row: Dictionary in GLYPH_ROWS:
		var area: Rect2i = glyph_row["area"]
		var characters: String = glyph_row["characters"]
		var glyph_rects := _find_glyph_rects(sheet, area, glyph_row.get("breaks", []))
		if glyph_rects.size() != characters.length():
			push_error("Row at y=%d: found %d glyphs on the sheet but %d characters ('%s')." % [
				area.position.y, glyph_rects.size(), characters.length(), characters])
			quit(1)
			return
		for index in characters.length():
			var rect: Rect2i = glyph_rects[index]
			_add_glyph(font, cache_size, characters.unicode_at(index), rect,
					int(glyph_row["baseline"]), rect.size.x + LETTER_SPACING)
			glyph_count += 1

	var error := ResourceSaver.save(font, FONT_PATH)
	if error != OK:
		push_error("Could not save %s (error %d)" % [FONT_PATH, error])
		quit(1)
		return
	print("Saved %s with %d glyphs." % [FONT_PATH, glyph_count])
	quit()


## Splits an area into glyphs: each run of columns that has ink is one glyph,
## trimmed to the rows that have ink.
func _find_glyph_rects(sheet: Image, area: Rect2i, breaks: Array) -> Array[Rect2i]:
	var rects: Array[Rect2i] = []
	var run_start := -1
	for x in range(area.position.x, area.end.x + 1):
		var has_ink := x < area.end.x and _column_has_ink(sheet, x, area)
		if has_ink and run_start >= 0 and breaks.has(x):
			rects.append(_trim_rows(sheet, Rect2i(run_start, area.position.y, x - run_start, area.size.y)))
			run_start = x
		elif has_ink and run_start < 0:
			run_start = x
		elif not has_ink and run_start >= 0:
			rects.append(_trim_rows(sheet, Rect2i(run_start, area.position.y, x - run_start, area.size.y)))
			run_start = -1
	return rects


func _column_has_ink(sheet: Image, x: int, area: Rect2i) -> bool:
	for y in range(area.position.y, area.end.y):
		if _is_ink(sheet, x, y):
			return true
	return false


func _trim_rows(sheet: Image, rect: Rect2i) -> Rect2i:
	var top := rect.end.y
	var bottom := rect.position.y - 1
	for y in range(rect.position.y, rect.end.y):
		for x in range(rect.position.x, rect.end.x):
			if _is_ink(sheet, x, y):
				top = mini(top, y)
				bottom = maxi(bottom, y)
	return Rect2i(rect.position.x, top, rect.size.x, bottom - top + 1)


func _is_ink(sheet: Image, x: int, y: int) -> bool:
	return sheet.get_pixel(x, y).a >= 0.5


## The sheet is drawn in black; the font texture must be white so Label and
## Button font colours tint it.
func _white_glyphs(sheet: Image) -> Image:
	var result := Image.create(sheet.get_width(), sheet.get_height(), false, Image.FORMAT_RGBA8)
	for y in sheet.get_height():
		for x in sheet.get_width():
			if _is_ink(sheet, x, y):
				result.set_pixel(x, y, Color.WHITE)
	return result


func _add_glyph(font: FontFile, cache_size: Vector2i, character: int, rect: Rect2i,
		baseline: int, advance: int) -> void:
	# A font without an outline file looks glyphs up by character code.
	var glyph := character
	font.set_glyph_advance(0, FIXED_SIZE, glyph, Vector2(advance, 0))
	if rect.has_area():
		font.set_glyph_offset(0, cache_size, glyph, Vector2(0, rect.position.y - (baseline + 1)))
		font.set_glyph_size(0, cache_size, glyph, Vector2(rect.size))
		font.set_glyph_uv_rect(0, cache_size, glyph, Rect2(rect))
		font.set_glyph_texture_idx(0, cache_size, glyph, 0)
