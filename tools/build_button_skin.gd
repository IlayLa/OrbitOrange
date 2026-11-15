extends SceneTree
## Rebuilds res://assets/ui/button_skin.png from the team's res://design/buttons.png.
##
## The source sheet draws its frames with icons inside them, so a plain 9-slice of
## the sheet would stretch the icons across every button. This script copies each
## frame's border and fill colours into clean 3x3 frames (1 px border, 1 px fill),
## laid out left to right:
##   x 0: normal  - black border, white fill (the "+" / "-" boxes, top row)
##   x 3: pressed - green border, pale green fill (the "PRESSED BUTTON" frame)
##   x 6: focus   - green border, transparent fill (drawn over the other states)
## assets/ui/ui_theme.tres cuts these frames with StyleBoxTexture region_rect.
##
## Run: godot --headless --path . -s tools/build_button_skin.gd

const SOURCE_PATH := "res://design/buttons.png"
const OUTPUT_PATH := "res://assets/ui/button_skin.png"
## A pixel on the border and one inside, per source frame.
const NORMAL_BORDER_PIXEL := Vector2i(42, 2)
const NORMAL_FILL_PIXEL := Vector2i(43, 3)
const PRESSED_BORDER_PIXEL := Vector2i(40, 36)
const PRESSED_FILL_PIXEL := Vector2i(41, 37)
const FRAME_SIZE := 3


func _init() -> void:
	var source := Image.load_from_file(ProjectSettings.globalize_path(SOURCE_PATH))
	source.convert(Image.FORMAT_RGBA8)
	var output := Image.create_empty(FRAME_SIZE * 3, FRAME_SIZE, false, Image.FORMAT_RGBA8)
	var green_border := source.get_pixelv(PRESSED_BORDER_PIXEL)
	_draw_frame(output, 0, source.get_pixelv(NORMAL_BORDER_PIXEL), source.get_pixelv(NORMAL_FILL_PIXEL))
	_draw_frame(output, 1, green_border, source.get_pixelv(PRESSED_FILL_PIXEL))
	_draw_frame(output, 2, green_border, Color(0, 0, 0, 0))
	var error := output.save_png(ProjectSettings.globalize_path(OUTPUT_PATH))
	if error != OK:
		push_error("Could not save %s (error %d)" % [OUTPUT_PATH, error])
	else:
		print("Wrote ", OUTPUT_PATH)
	quit(error)


func _draw_frame(image: Image, frame_index: int, border: Color, fill: Color) -> void:
	var left := frame_index * FRAME_SIZE
	for y in FRAME_SIZE:
		for x in FRAME_SIZE:
			var is_border := x == 0 or y == 0 or x == FRAME_SIZE - 1 or y == FRAME_SIZE - 1
			image.set_pixel(left + x, y, border if is_border else fill)
