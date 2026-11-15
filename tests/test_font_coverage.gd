extends RefCounted
## Every character the game can show must be in the pixel font
## (res://assets/ui/pixel_font.tres). A missing one falls back to a taller
## system font and breaks the line's look. Scans the string values in
## data/*.json and the string literals in scripts/**/*.gd and scenes/**/*.tscn
## text. Comments, StringName (&"...") and NodePath (^"...") literals are
## skipped, since they are never drawn.
##
## When this fails, draw the character on design/template.png (or add a
## stand-in in tools/build_pixel_font.gd) and rebuild the font.

const FONT_PATH := "res://assets/ui/pixel_font.tres"
const DATA_FOLDER := "res://data"
const SCRIPT_FOLDER := "res://scripts"
const SCENE_FOLDER := "res://scenes"


func run_tests(report: TestReport) -> void:
	var font: FontFile = load(FONT_PATH)
	report.check(font != null, "the pixel font loads")
	if font == null:
		return

	# character -> first file it was seen in
	var used := {}
	for path in _files_in(DATA_FOLDER, ".json"):
		_collect_json(JSON.parse_string(FileAccess.get_file_as_string(path)), path, used)
	for path in _files_in(SCRIPT_FOLDER, ".gd"):
		_collect_gdscript(FileAccess.get_file_as_string(path), path, used)
	for path in _files_in(SCENE_FOLDER, ".tscn"):
		_collect_scene_text(FileAccess.get_file_as_string(path), path, used)
	report.check(used.size() > 40, "the scan found the game's text (%d characters)" % used.size())

	var missing: Array[String] = []
	for character: String in used:
		if not font.has_char(character.unicode_at(0)):
			missing.append("'%s' (U+%04X, in %s)" % [character, character.unicode_at(0), used[character]])
	report.check(missing.is_empty(), "every character in game text is in the pixel font; missing: %s" % ", ".join(missing))

	# Spot checks of the glyph fixes.
	for character in ["γ", "θ", "Δ", "≈", "g", "q"]:
		report.check(font.has_char(character.unicode_at(0)), "the pixel font has %s" % character)


func _files_in(folder: String, extension: String) -> Array[String]:
	var paths: Array[String] = []
	for file_name in DirAccess.get_files_at(folder):
		if file_name.ends_with(extension):
			paths.append(folder.path_join(file_name))
	for sub_folder in DirAccess.get_directories_at(folder):
		paths.append_array(_files_in(folder.path_join(sub_folder), extension))
	return paths


func _add_text(text: String, path: String, used: Dictionary) -> void:
	for character in text:
		if character.unicode_at(0) > 32 and not used.has(character):
			used[character] = path.get_file()


func _collect_json(value: Variant, path: String, used: Dictionary) -> void:
	if value is String:
		_add_text(value, path, used)
	elif value is Array:
		for item: Variant in value:
			_collect_json(item, path, used)
	elif value is Dictionary:
		for key: Variant in value:
			_collect_json(value[key], path, used)


## Walks the source once, skipping comments and collecting the text of each
## "..." or '...' literal (escapes like \n are left out).
func _collect_gdscript(source: String, path: String, used: Dictionary) -> void:
	var index := 0
	var length := source.length()
	while index < length:
		var character := source[index]
		if character == "#":
			while index < length and source[index] != "\n":
				index += 1
		elif character == "\"" or character == "'":
			var is_name := index > 0 and (source[index - 1] == "&" or source[index - 1] == "^")
			var quote := character
			if source.substr(index, 3) == quote.repeat(3):
				quote = quote.repeat(3)
			index += quote.length()
			var text := ""
			while index < length and source.substr(index, quote.length()) != quote:
				if source[index] == "\\":
					index += 2
					continue
				text += source[index]
				index += 1
			index += quote.length()
			if not is_name:
				_add_text(text, path, used)
		else:
			index += 1


func _collect_scene_text(source: String, path: String, used: Dictionary) -> void:
	var regex := RegEx.create_from_string("(?m)^(text|placeholder_text|tooltip_text) = \"((?:[^\"\\\\]|\\\\.)*)\"")
	for found in regex.search_all(source):
		_add_text(found.get_string(2).replace("\\n", " "), path, used)
