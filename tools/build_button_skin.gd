extends SceneTree
## Rebuilds the button skin pixels inside res://assets/ui/ui_theme.tres from the
## team's res://design/buttons.png. The pixels are kept in the theme (an Image
## sub-resource) rather than in a PNG, because the project theme loads before a
## fresh clone's first import, when no imported PNG exists yet.
##
## The source sheet draws its frames with icons inside them, so a plain 9-slice of
## the sheet would stretch the icons across every button. This script copies each
## frame's border and fill colours into clean 3x3 frames (1 px border, 1 px fill),
## laid out left to right:
##   x 0: normal  - black border, white fill (the "+" / "-" boxes, top row)
##   x 3: pressed - green border, pale green fill (the "PRESSED BUTTON" frame)
##   x 6: focus   - green border, transparent fill (drawn over the other states)
##   x 9: hover   - orange border (the game's accent), white fill
## The theme's StyleBoxTextures cut these frames with region_rect.
##
## Run: godot --headless --path . -s tools/build_button_skin.gd

const SOURCE_PATH := "res://design/buttons.png"
const THEME_PATH := "res://assets/ui/ui_theme.tres"
## The line of the theme's first Image sub-resource that holds the RGBA8 pixels.
const DATA_LINE_PREFIX := "\"data\": PackedByteArray("
## A pixel on the border and one inside, per source frame.
const NORMAL_BORDER_PIXEL := Vector2i(42, 2)
const NORMAL_FILL_PIXEL := Vector2i(43, 3)
const PRESSED_BORDER_PIXEL := Vector2i(40, 36)
const PRESSED_FILL_PIXEL := Vector2i(41, 37)
const FRAME_SIZE := 3
const FRAME_COUNT := 4
## The sheet draws no hover state; the game's orange accent marks it.
const HOVER_BORDER_COLOR := Color("ff5000")


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	source.convert(Image.FORMAT_RGBA8)
	var output := Image.create_empty(FRAME_SIZE * FRAME_COUNT, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var green_border := source.get_pixelv(PRESSED_BORDER_PIXEL)
	_draw_frame(output, 0, source.get_pixelv(NORMAL_BORDER_PIXEL), source.get_pixelv(NORMAL_FILL_PIXEL))
	_draw_frame(output, 1, green_border, source.get_pixelv(PRESSED_FILL_PIXEL))
	_draw_frame(output, 2, green_border, Color(0, 0, 0, 0))
	_draw_frame(output, 3, HOVER_BORDER_COLOR, source.get_pixelv(NORMAL_FILL_PIXEL))
	var error := _write_pixels_into_theme(output)
	if error != OK:
		push_error("Could not update %s (error %d)" % [THEME_PATH, error])
	else:
		print("Updated the button skin in ", THEME_PATH)
	quit(error)


func _draw_frame(image: Image, frame_index: int, border: Color, fill: Color) -> void:
	var left := frame_index * FRAME_SIZE
	for y in FRAME_SIZE:
		for x in FRAME_SIZE:
			var is_border := x == 0 or y == 0 or x == FRAME_SIZE - 1 or y == FRAME_SIZE - 1
			image.set_pixel(left + x, y, border if is_border else fill)


func _write_pixels_into_theme(image: Image) -> Error:
	var theme_text := FileAccess.get_file_as_string(THEME_PATH)
	if theme_text.is_empty():
		return FileAccess.get_open_error()
	var lines := theme_text.split("\n")
	var byte_texts: Array[String] = []
	for byte in image.get_data():
		byte_texts.append(str(byte))
	var found := false
	for line_index in lines.size():
		if lines[line_index].begins_with(DATA_LINE_PREFIX):
			lines[line_index] = DATA_LINE_PREFIX + ", ".join(byte_texts) + "),"
			found = true
			# Only the first Image is the skin; later ones (the arrow) stay.
			break
	if not found:
		return ERR_PARSE_ERROR
	var file := FileAccess.open(THEME_PATH, FileAccess.WRITE)
	if file == null:
		return FileAccess.get_open_error()
	file.store_string("\n".join(lines))
	return OK
