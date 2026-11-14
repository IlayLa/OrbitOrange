extends SceneTree
## Generates six anonymous pixel astronaut portraits; existing art is preserved.
const PORTRAIT_NAMES := ["failure", "partial_success", "success", "great_success", "perfect", "scientific_breakthrough"]

func _init() -> void:
	DirAccess.make_dir_recursive_absolute("res://assets/placeholders/portraits")
	for band_index in PORTRAIT_NAMES.size():
		var path := "res://assets/placeholders/portraits/%s.png" % PORTRAIT_NAMES[band_index]
		if FileAccess.file_exists(path):
			continue
		var portrait := Image.create(32, 32, false, Image.FORMAT_RGBA8)
		portrait.fill(Color("3e5e79"))
		portrait.fill_rect(Rect2i(6, 3, 20, 23), Color("c2c2c2"))
		portrait.fill_rect(Rect2i(8, 6, 16, 17), Color("000000"))
		portrait.fill_rect(Rect2i(10, 8, 12, 13), Color("a49674"))
		portrait.fill_rect(Rect2i(12, 12, 2, 2), Color("000000"))
		portrait.fill_rect(Rect2i(18, 12, 2, 2), Color("000000"))
		portrait.fill_rect(Rect2i(13, 17, 6, 1), Color("000000"))
		if band_index >= 2:
			portrait.fill_rect(Rect2i(14, 18, 4, 1), Color("000000"))
		if band_index == 0:
			portrait.fill_rect(Rect2i(14, 16, 4, 1), Color("000000"))
		portrait.fill_rect(Rect2i(5, 26, 22, 6), Color("ff5000"))
		for badge_index in band_index:
			portrait.fill_rect(Rect2i(4 + badge_index * 5, 28, 3, 2), Color("ffffff"))
		if band_index == 5:
			portrait.fill_rect(Rect2i(2, 2, 3, 3), Color("ff5000"))
			portrait.fill_rect(Rect2i(27, 2, 3, 3), Color("ff5000"))
		var error := portrait.save_png(path)
		if error != OK:
			push_error("Could not save portrait: " + path)
			quit(1)
			return
	quit(0)
