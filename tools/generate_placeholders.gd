extends SceneTree
## Draws a simple placeholder icon for every part in data/parts.json, so that
## every icon_path in the catalogue points at a real file.
##
## How to run, from the project folder:
##     godot --headless --script tools/generate_placeholders.gd
##     godot --headless --import
## Run it again after adding parts. Real art replaces a placeholder by saving
## a PNG with the same file name. Icons that already exist are left alone, so
## real art is never overwritten.

const PARTS_FILE_PATH := "res://data/parts.json"
const ICON_SIZE_PIXELS := 16
const BORDER_COLOR := Color("202020")
const FALLBACK_COLOR := Color("808080")
const COLOR_BY_CATEGORY := {
	"engine": Color("ff5000"),
	"tank": Color("c2c2c2"),
	"telemetry": Color("4171c4"),
	"science": Color("44902d"),
}


func _init() -> void:
	var parts: Variant = JSON.parse_string(FileAccess.get_file_as_string(PARTS_FILE_PATH))
	if not parts is Array:
		push_error("Could not read " + PARTS_FILE_PATH)
		quit(1)
		return

	var created_icon_count := 0
	for part: Dictionary in parts:
		var icon_path: String = part.get("icon_path", "")
		if icon_path == "" or FileAccess.file_exists(icon_path):
			continue
		DirAccess.make_dir_recursive_absolute(icon_path.get_base_dir())
		var icon_color: Color = COLOR_BY_CATEGORY.get(part.get("category", ""), FALLBACK_COLOR)
		create_icon_image(icon_color).save_png(icon_path)
		created_icon_count += 1

	print("Created %d placeholder icons." % created_icon_count)
	quit(0)


## A filled square with a one-pixel dark border.
func create_icon_image(fill_color: Color) -> Image:
	var image := Image.create(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS, false, Image.FORMAT_RGBA8)
	image.fill(BORDER_COLOR)
	image.fill_rect(Rect2i(1, 1, ICON_SIZE_PIXELS - 2, ICON_SIZE_PIXELS - 2), fill_color)
	return image
