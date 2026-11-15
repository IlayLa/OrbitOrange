class_name RocketStackPreview
extends Control
## Draws the rocket as a stack of blocks: the bottom stage at the bottom, each
## stage as an engine with its tank above it, the payload parts above the top
## stage, and a nose cone on top.
##
## Each stage carries a 7 x 7 warning lamp (WarningLamps): a red cross when a
## sentence of the plan about that stage blocks the launch, an amber triangle
## for advice, a green dot when it is fine. On the design screen, hovering a
## lamp shows its sentence, clicking pins it and Tab steps from lamp to lamp.
##
## Two uses:
##   - the rocket design screen: is_interactive = true. Part names are written
##     beside the stack, a click on a block reports which installed part was
##     clicked, and a click on a stage tag ("S1") reports the stage.
##   - the overview monitor: is_interactive = false. A small picture only.
## The preview changes nothing itself; RocketDesign.gd reacts to its signals.

signal engine_clicked(stage_id: int)
signal tank_clicked(stage_id: int)
signal payload_clicked(payload_index: int)
signal stage_tag_clicked(stage_id: int)

enum BlockKind { ENGINE, TANK, MISSING_TANK, PAYLOAD, STAGE_TAG }

## Heights of the blocks, in units. One unit becomes as many pixels as fit.
const ENGINE_HEIGHT_UNITS := 1.0
const TANK_HEIGHT_UNITS := 1.6
const SOLID_MOTOR_HEIGHT_UNITS := 2.0
const PAYLOAD_HEIGHT_UNITS := 0.7
const NOSE_CONE_HEIGHT_UNITS := 0.9
const LARGEST_UNIT_PIXELS := 30.0
const MARGIN_PIXELS := 6.0
const STAGE_TAG_WIDTH_PIXELS := 18.0
const LABEL_FONT_SIZE_PIXELS := 8
const EMPTY_FONT_SIZE_PIXELS := 9
## The part icons are 40 x 40 (tools/build_part_icons.gd), drawn at exactly
## half size like on the part cards, so every icon has the same pixel size.
const ICON_SIZE_PIXELS := 20.0
## A block (or run of payload blocks) shows its icon when the drawn art,
## without the icon's transparent margin, fits inside it with this much room.
const ICON_ROOM_PIXELS := 1.0
## Room to the right of the stack for the lamps, before the part names.
const LAMP_COLUMN_WIDTH_PIXELS := 11.0
const BUBBLE_WIDTH_PIXELS := 160.0
const BUBBLE_MAXIMUM_LINE_COUNT := 4

const COLOR_TANK := Color("d9dde3")
const COLOR_ENGINE := Color("5b6470")
const COLOR_SOLID_MOTOR := Color("b9a27a")
const COLOR_PAYLOAD := Color("7fb3d9")
const COLOR_NOSE_CONE := Color("e9ecef")
const COLOR_OUTLINE := Color("1b2430")
const COLOR_MISSING := Color("e23a1a")

const ENGINE_TYPE_SOLID := "solid"

## True on the rocket design screen: names are drawn and clicks are reported.
var is_interactive: bool = false
## The stage that receives the next tank, drawn with an orange outline. 0 for none.
var selected_stage_id: int = 0

var _design: RocketDesign
## One Dictionary per clickable or drawn block:
##   "kind" (BlockKind), "rect" (Rect2), "stage_id" (int),
##   "payload_index" (int), "part_id" (String)
var _blocks: Array[Dictionary] = []
var _nose_cone_points: PackedVector2Array = PackedVector2Array()
## Runs of identical payload parts, drawn with one icon and one label
## ("Basic altimeter ×9"). One Dictionary each: "rect" (Rect2, all blocks of
## the run), "part_id", "count", "block_indices" (Array of int into _blocks).
var _payload_groups: Array[Dictionary] = []
## Icon path -> {"texture": Texture2D, "art_size": Vector2, the drawn size
## of the icon's opaque pixels}, or {} when there is no icon. The textures
## must outlive _draw(): the canvas only keeps the texture's RID, and a
## texture freed after _draw() draws as a white square.
static var _icon_cache: Dictionary = {}
var _hovered_block_index: int = -1
## Lamps of the plan, from WarningLamps.lamps_from_summary.
var _lamps: Array[Dictionary] = []
## One Dictionary per drawn lamp: "rect" (Rect2, the 7 x 7 lamp), "severity"
## and "sentence". Rebuilt with the blocks.
var _lamp_spots: Array[Dictionary] = []
var _hovered_lamp_index: int = -1
var _pinned_lamp_index: int = -1
var _focused_lamp_index: int = -1


func _ready() -> void:
	clip_contents = true
	mouse_filter = Control.MOUSE_FILTER_STOP if is_interactive else Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_ALL if is_interactive else Control.FOCUS_NONE
	mouse_exited.connect(_on_mouse_exited)
	resized.connect(_rebuild_blocks)


## Shows this design. Call again whenever the design or the selection changes.
func show_design(design: RocketDesign, new_selected_stage_id: int = 0) -> void:
	_design = design
	selected_stage_id = new_selected_stage_id
	_rebuild_blocks()


## Shows these warning lamps (WarningLamps.lamps_from_summary) on the stages.
func show_lamps(lamps: Array[Dictionary]) -> void:
	_lamps = lamps
	_rebuild_lamp_spots()
	queue_redraw()


## The drawn lamps, for tests: "rect", "severity" and "sentence" each.
func lamp_spots() -> Array[Dictionary]:
	return _lamp_spots


## The blocks of the given kind, for tests and for hit testing.
func blocks_of_kind(block_kind: BlockKind) -> Array[Dictionary]:
	var matching_blocks: Array[Dictionary] = []
	for block in _blocks:
		if block["kind"] == block_kind:
			matching_blocks.append(block)
	return matching_blocks


static func is_solid_engine(engine_part_id: String) -> bool:
	var stats: Dictionary = GameData.part(engine_part_id).get("stats", {})
	return stats.get("engine_type", "") == ENGINE_TYPE_SOLID


func _rebuild_blocks() -> void:
	_blocks.clear()
	_payload_groups.clear()
	_nose_cone_points = PackedVector2Array()
	_hovered_block_index = -1
	if _design == null or (_design.stages.is_empty() and _design.payload_part_ids.is_empty()):
		_rebuild_lamp_spots()
		queue_redraw()
		return

	# Total height in units decides how many pixels one unit gets.
	var total_height_units: float = NOSE_CONE_HEIGHT_UNITS
	total_height_units += PAYLOAD_HEIGHT_UNITS * _design.payload_part_ids.size()
	for stage in _design.stages:
		total_height_units += _stage_height_units(stage)
	var available_height_pixels: float = size.y - 2.0 * MARGIN_PIXELS
	var unit_pixels: float = minf(LARGEST_UNIT_PIXELS, available_height_pixels / total_height_units)

	var stack_width_pixels: float = clampf(unit_pixels * 1.8, 10.0, size.x * 0.5)
	var stack_left_pixels: float = (size.x - stack_width_pixels) * 0.5
	if is_interactive:
		# Names are written to the right of the stack, so the stack moves left.
		stack_left_pixels = MARGIN_PIXELS + STAGE_TAG_WIDTH_PIXELS + 4.0
	var stack_height_pixels: float = total_height_units * unit_pixels
	var next_bottom_pixels: float = size.y - MARGIN_PIXELS - maxf(0.0, (available_height_pixels - stack_height_pixels) * 0.5)

	for stage in _design.stages:
		var stage_bottom_pixels: float = next_bottom_pixels
		if is_solid_engine(stage.engine_part_id):
			var motor_height_pixels: float = SOLID_MOTOR_HEIGHT_UNITS * unit_pixels
			next_bottom_pixels -= motor_height_pixels
			_add_block(BlockKind.ENGINE, Rect2(stack_left_pixels, next_bottom_pixels, stack_width_pixels, motor_height_pixels),
					stage.stage_id, -1, stage.engine_part_id)
		else:
			var engine_height_pixels: float = ENGINE_HEIGHT_UNITS * unit_pixels
			next_bottom_pixels -= engine_height_pixels
			_add_block(BlockKind.ENGINE, Rect2(stack_left_pixels, next_bottom_pixels, stack_width_pixels, engine_height_pixels),
					stage.stage_id, -1, stage.engine_part_id)
			var tank_height_pixels: float = TANK_HEIGHT_UNITS * unit_pixels
			next_bottom_pixels -= tank_height_pixels
			var tank_kind: BlockKind = BlockKind.MISSING_TANK if stage.tank_part_id.is_empty() else BlockKind.TANK
			_add_block(tank_kind, Rect2(stack_left_pixels, next_bottom_pixels, stack_width_pixels, tank_height_pixels),
					stage.stage_id, -1, stage.tank_part_id)
		if is_interactive:
			_add_block(BlockKind.STAGE_TAG,
					Rect2(MARGIN_PIXELS, next_bottom_pixels, STAGE_TAG_WIDTH_PIXELS, stage_bottom_pixels - next_bottom_pixels),
					stage.stage_id, -1, "")

	var payload_width_pixels: float = stack_width_pixels * 0.8
	var payload_left_pixels: float = stack_left_pixels + (stack_width_pixels - payload_width_pixels) * 0.5
	for payload_index in _design.payload_part_ids.size():
		var payload_height_pixels: float = PAYLOAD_HEIGHT_UNITS * unit_pixels
		next_bottom_pixels -= payload_height_pixels
		var payload_rect := Rect2(payload_left_pixels, next_bottom_pixels, payload_width_pixels, payload_height_pixels)
		var payload_part_id: String = _design.payload_part_ids[payload_index]
		_add_block(BlockKind.PAYLOAD, payload_rect, 0, payload_index, payload_part_id)
		if not _payload_groups.is_empty() and _payload_groups[-1]["part_id"] == payload_part_id:
			var group: Dictionary = _payload_groups[-1]
			group["rect"] = (group["rect"] as Rect2).merge(payload_rect)
			group["count"] += 1
			group["block_indices"].append(_blocks.size() - 1)
		else:
			_payload_groups.append({
				"rect": payload_rect, "part_id": payload_part_id, "count": 1, "block_indices": [_blocks.size() - 1],
			})

	var nose_cone_width_pixels: float = stack_width_pixels if _design.payload_part_ids.is_empty() else payload_width_pixels
	var nose_cone_left_pixels: float = stack_left_pixels + (stack_width_pixels - nose_cone_width_pixels) * 0.5
	var nose_cone_height_pixels: float = NOSE_CONE_HEIGHT_UNITS * unit_pixels
	_nose_cone_points = PackedVector2Array([
		Vector2(nose_cone_left_pixels, next_bottom_pixels),
		Vector2(nose_cone_left_pixels + nose_cone_width_pixels, next_bottom_pixels),
		Vector2(nose_cone_left_pixels + nose_cone_width_pixels * 0.5, next_bottom_pixels - nose_cone_height_pixels),
	])
	_rebuild_lamp_spots()
	queue_redraw()


## One lamp beside each stage, and one beside the nose cone for sentences
## about the whole rocket. A pinned lamp stays pinned while its sentence
## lasts; the focused lamp keeps the focus while its stage (or the rocket
## lamp) is still there.
func _rebuild_lamp_spots() -> void:
	var pinned_sentence := ""
	if _pinned_lamp_index >= 0 and _pinned_lamp_index < _lamp_spots.size():
		pinned_sentence = _lamp_spots[_pinned_lamp_index]["sentence"]
	var focused_stage_id: int = -2
	if _focused_lamp_index >= 0 and _focused_lamp_index < _lamp_spots.size():
		focused_stage_id = _lamp_spots[_focused_lamp_index]["stage_id"]
	_lamp_spots.clear()
	_hovered_lamp_index = -1
	_focused_lamp_index = -1
	_pinned_lamp_index = -1
	if _design == null or _blocks.is_empty():
		return
	var lamp_left_pixels: float = roundf(_stack_right_pixels() + 3.0)
	for stage_index in _design.stages.size():
		var stage: Stage = _design.stages[stage_index]
		var stage_rect: Rect2 = _stage_rect(stage.stage_id)
		var severity: int = WarningLamps.worst_severity_for_stage(_lamps, stage_index + 1)
		var sentence: String = WarningLamps.sentences_for_stage(_lamps, stage_index + 1)
		if sentence.is_empty():
			sentence = "Stage %d: no problems found." % (stage_index + 1)
		_lamp_spots.append({
			"rect": Rect2(Vector2(lamp_left_pixels, roundf(stage_rect.get_center().y - 3.0)), Vector2(7, 7)),
			"severity": severity,
			"sentence": sentence,
			"stage_id": stage.stage_id,
		})
	var rocket_sentences: PackedStringArray = []
	var rocket_severity: int = WarningLamps.Severity.OK
	for lamp in _lamps:
		if lamp["stage_number"] == 0 and lamp["pulse_number"] == 0:
			rocket_sentences.append(lamp["sentence"])
			rocket_severity = maxi(rocket_severity, lamp["severity"])
	if not rocket_sentences.is_empty() and _nose_cone_points.size() == 3:
		_lamp_spots.append({
			"rect": Rect2(Vector2(lamp_left_pixels, roundf(_nose_cone_points[0].y - 8.0)), Vector2(7, 7)),
			"severity": rocket_severity,
			"sentence": " ".join(rocket_sentences),
			"stage_id": -1,
		})
	for lamp_index in _lamp_spots.size():
		if _lamp_spots[lamp_index]["sentence"] == pinned_sentence and not pinned_sentence.is_empty():
			_pinned_lamp_index = lamp_index
		if _lamp_spots[lamp_index]["stage_id"] == focused_stage_id:
			_focused_lamp_index = lamp_index


func _stack_right_pixels() -> float:
	var widest_right_pixels: float = 0.0
	for block in _blocks:
		if block["kind"] != BlockKind.STAGE_TAG:
			var block_rect: Rect2 = block["rect"]
			widest_right_pixels = maxf(widest_right_pixels, block_rect.end.x)
	return widest_right_pixels


func _stage_rect(stage_id: int) -> Rect2:
	var has_stage_rect := false
	var stage_rect := Rect2()
	for block in _blocks:
		if block["stage_id"] != stage_id or block["kind"] == BlockKind.PAYLOAD or block["kind"] == BlockKind.STAGE_TAG:
			continue
		var block_rect: Rect2 = block["rect"]
		stage_rect = stage_rect.merge(block_rect) if has_stage_rect else block_rect
		has_stage_rect = true
	return stage_rect


func _stage_height_units(stage: Stage) -> float:
	if is_solid_engine(stage.engine_part_id):
		return SOLID_MOTOR_HEIGHT_UNITS
	return ENGINE_HEIGHT_UNITS + TANK_HEIGHT_UNITS


func _add_block(block_kind: BlockKind, block_rect: Rect2, stage_id: int, payload_index: int, part_id: String) -> void:
	_blocks.append({
		"kind": block_kind,
		"rect": block_rect,
		"stage_id": stage_id,
		"payload_index": payload_index,
		"part_id": part_id,
	})


func _draw() -> void:
	if _blocks.is_empty():
		if is_interactive:
			_draw_text(Vector2(MARGIN_PIXELS, size.y * 0.5), "No parts yet.", size.x - 2.0 * MARGIN_PIXELS,
					EMPTY_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT)
			_draw_text(Vector2(MARGIN_PIXELS, size.y * 0.5 + 12.0), "Pick an engine from the list.", size.x - 2.0 * MARGIN_PIXELS,
					EMPTY_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT)
		return

	for block_index in _blocks.size():
		_draw_block(_blocks[block_index], block_index == _hovered_block_index)
	for group in _payload_groups:
		_draw_payload_group(group)
	if _nose_cone_points.size() == 3:
		draw_colored_polygon(_nose_cone_points, COLOR_NOSE_CONE)
		draw_polyline(_nose_cone_points + PackedVector2Array([_nose_cone_points[0]]), COLOR_OUTLINE, 1.0)
	_draw_selection_outline()
	_draw_next_tank_chip()
	_draw_lamps()


func _draw_lamps() -> void:
	for lamp_index in _lamp_spots.size():
		var lamp_spot: Dictionary = _lamp_spots[lamp_index]
		var lamp_rect: Rect2 = lamp_spot["rect"]
		var severity: int = lamp_spot["severity"]
		PixelGlyphs.draw_glyph(self, PixelGlyphs.lamp_glyph_name(severity), lamp_rect.position, PixelGlyphs.lamp_color(severity))
		if lamp_index == _pinned_lamp_index:
			draw_rect(lamp_rect.grow(2.0), ScreenLayout.COLOR_ACCENT_ORANGE, false, 1.0)
	if not is_interactive:
		return
	var shown_index: int = _shown_lamp_index()
	if shown_index < 0:
		return
	if shown_index == _focused_lamp_index and shown_index != _pinned_lamp_index:
		var focused_rect: Rect2 = _lamp_spots[shown_index]["rect"]
		draw_rect(focused_rect.grow(2.0), ScreenLayout.COLOR_MONITOR_GRID_LINE, false, 1.0)
	_draw_lamp_bubble(_lamp_spots[shown_index])


## The lamp whose sentence is shown: under the mouse, focused or pinned; -1 for none.
func _shown_lamp_index() -> int:
	if _hovered_lamp_index >= 0:
		return _hovered_lamp_index
	if _focused_lamp_index >= 0:
		return _focused_lamp_index
	return _pinned_lamp_index


func _draw_lamp_bubble(lamp_spot: Dictionary) -> void:
	var lamp_rect: Rect2 = lamp_spot["rect"]
	var severity: int = lamp_spot["severity"]
	var lines: Array[String] = PixelGlyphs.wrap_lines(lamp_spot["sentence"], BUBBLE_WIDTH_PIXELS - 6.0, BUBBLE_MAXIMUM_LINE_COUNT)
	var bubble_size := Vector2(BUBBLE_WIDTH_PIXELS, 4.0 + lines.size() * PixelGlyphs.LINE_HEIGHT_PIXELS)
	# Anchored to the top or bottom edge of the preview, whichever is farther
	# from the lamp, so it does not cover the stage or its labels.
	var is_lamp_in_lower_half: bool = lamp_rect.get_center().y > size.y * 0.5
	var bubble_top: float = 2.0 if is_lamp_in_lower_half else size.y - bubble_size.y - 2.0
	var bubble_rect := Rect2(Vector2(roundf(size.x - bubble_size.x - 2.0), roundf(bubble_top)), bubble_size)
	draw_rect(bubble_rect, Color(ScreenLayout.COLOR_SPACE_BLACK, 0.9))
	draw_rect(bubble_rect, PixelGlyphs.lamp_color(severity), false, 1.0)
	for line_index in lines.size():
		PixelGlyphs.draw_text(self, bubble_rect.position + Vector2(3, 2 + line_index * PixelGlyphs.LINE_HEIGHT_PIXELS),
				lines[line_index], ScreenLayout.COLOR_TEXT_LIGHT)


func _draw_block(block: Dictionary, is_hovered: bool) -> void:
	var block_rect: Rect2 = block["rect"]
	var block_kind: BlockKind = block["kind"]
	var part_id: String = block["part_id"]
	var stage_id: int = block["stage_id"]

	match block_kind:
		BlockKind.STAGE_TAG:
			var is_selected: bool = stage_id == selected_stage_id
			var tag_color: Color = ScreenLayout.COLOR_ACCENT_ORANGE if is_selected else ScreenLayout.COLOR_PANEL_DARK_BLUE
			if is_hovered and not is_selected:
				tag_color = tag_color.lightened(0.25)
			draw_rect(block_rect.grow(-1.0), tag_color)
			_draw_text(block_rect.position + Vector2(2.0, block_rect.size.y * 0.5 + 3.0), "S%d" % _stage_number(stage_id),
					block_rect.size.x - 2.0, LABEL_FONT_SIZE_PIXELS, ScreenLayout.COLOR_TEXT_LIGHT)
			return
		BlockKind.MISSING_TANK:
			draw_rect(block_rect, COLOR_MISSING, false, 1.0)
			draw_line(block_rect.position, block_rect.end, COLOR_MISSING, 1.0)
			if is_interactive:
				_draw_label(block_rect, "no tank: pick one under MAT", COLOR_MISSING)
			return
		BlockKind.ENGINE:
			if is_solid_engine(part_id):
				draw_rect(block_rect, COLOR_SOLID_MOTOR)
				draw_rect(block_rect, COLOR_OUTLINE, false, 1.0)
			else:
				# A liquid engine is drawn as a nozzle: narrow at the top, wide at the bottom.
				var nozzle_points := PackedVector2Array([
					Vector2(block_rect.position.x + block_rect.size.x * 0.3, block_rect.position.y),
					Vector2(block_rect.position.x + block_rect.size.x * 0.7, block_rect.position.y),
					Vector2(block_rect.end.x - block_rect.size.x * 0.08, block_rect.end.y),
					Vector2(block_rect.position.x + block_rect.size.x * 0.08, block_rect.end.y),
				])
				draw_colored_polygon(nozzle_points, COLOR_ENGINE)
				draw_polyline(nozzle_points + PackedVector2Array([nozzle_points[0]]), COLOR_OUTLINE, 1.0)
		BlockKind.TANK:
			draw_rect(block_rect, COLOR_TANK)
			draw_rect(block_rect, COLOR_OUTLINE, false, 1.0)
		BlockKind.PAYLOAD:
			draw_rect(block_rect, COLOR_PAYLOAD)
			draw_rect(block_rect, COLOR_OUTLINE, false, 1.0)
			# The icon and the label are drawn once per run of identical parts.
			if is_hovered:
				draw_rect(block_rect, ScreenLayout.COLOR_WARNING_RED, false, 2.0)
			return

	_draw_icon(block_rect, part_id, block_kind == BlockKind.ENGINE)
	if is_interactive:
		var part: Dictionary = GameData.part(part_id)
		var label_color: Color = ScreenLayout.COLOR_WARNING_RED if is_hovered else ScreenLayout.COLOR_TEXT_LIGHT
		var label_text: String = short_part_name(part.get("name", part_id))
		if is_hovered:
			label_text = "remove: " + label_text
		_draw_label(block_rect, label_text, label_color)
		if is_hovered:
			draw_rect(block_rect, ScreenLayout.COLOR_WARNING_RED, false, 2.0)


## One icon and one label for a run of identical payload parts. The label
## counts the parts ("Basic altimeter ×9"); over a hovered part it names the
## one part a click removes.
func _draw_payload_group(group: Dictionary) -> void:
	var group_rect: Rect2 = group["rect"]
	var part_id: String = group["part_id"]
	_draw_icon(group_rect, part_id)
	if not is_interactive:
		return
	var label_text: String = short_part_name(GameData.part(part_id).get("name", part_id))
	var is_hovered: bool = group["block_indices"].has(_hovered_block_index)
	if is_hovered:
		label_text = "remove: " + label_text
	elif group["count"] > 1:
		label_text += " ×%d" % group["count"]
	_draw_label(group_rect, label_text, ScreenLayout.COLOR_WARNING_RED if is_hovered else ScreenLayout.COLOR_TEXT_LIGHT)


## The icon of the part in the middle of the block. With has_plate, on a
## light plate the size of the art: engine art is grey on the grey nozzle.
func _draw_icon(block_rect: Rect2, part_id: String, has_plate: bool = false) -> void:
	var icon_entry: Dictionary = _icon_entry(GameData.part(part_id).get("icon_path", ""))
	if icon_entry.is_empty():
		return
	var art_size: Vector2 = icon_entry["art_size"]
	if art_size.x + 2.0 * ICON_ROOM_PIXELS > block_rect.size.x or art_size.y + 2.0 * ICON_ROOM_PIXELS > block_rect.size.y:
		return
	var icon: Texture2D = icon_entry["texture"]
	# On whole game pixels, so that the half-size icon pixels stay square.
	var icon_position: Vector2 = (block_rect.get_center() - Vector2(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS) * 0.5).round()
	if has_plate:
		var plate_size: Vector2 = (art_size + Vector2(2.0, 2.0) * ICON_ROOM_PIXELS).ceil()
		var plate_rect := Rect2((block_rect.get_center() - plate_size * 0.5).round(), plate_size)
		draw_rect(plate_rect, COLOR_NOSE_CONE)
		draw_rect(plate_rect, COLOR_OUTLINE, false, 1.0)
	draw_texture_rect(icon, Rect2(icon_position, Vector2(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS)), false)


static func _icon_entry(icon_path: String) -> Dictionary:
	if icon_path.is_empty():
		return {}
	if not _icon_cache.has(icon_path):
		var entry: Dictionary = {}
		if ResourceLoader.exists(icon_path):
			var texture: Texture2D = load(icon_path)
			var art_size := Vector2(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS)
			var image: Image = texture.get_image()
			if image != null and not image.is_empty():
				art_size = Vector2(image.get_used_rect().size) * ICON_SIZE_PIXELS / float(image.get_width())
			entry = {"texture": texture, "art_size": art_size}
		_icon_cache[icon_path] = entry
	return _icon_cache[icon_path]


## The text of the "next tank" chip, or "" when no stage is selected: the
## selected stage (orange outline and tag) receives the next tank, and a
## click on another stage tag changes it.
func next_tank_text() -> String:
	if not is_interactive or selected_stage_id == 0 or _stage_number(selected_stage_id) == 0:
		return ""
	return "next tank → S%d" % _stage_number(selected_stage_id)


## A small chip at the top left of the preview, in the orange of the
## selected stage, naming the stage that gets the next tank.
func _draw_next_tank_chip() -> void:
	var chip_text: String = next_tank_text()
	if chip_text.is_empty():
		return
	var chip_rect := Rect2(Vector2(2, 2), Vector2(PixelGlyphs.chip_width("fuel", chip_text) + 4.0, 11.0))
	draw_rect(chip_rect, Color(ScreenLayout.COLOR_SPACE_BLACK, 0.8))
	draw_rect(chip_rect, ScreenLayout.COLOR_ACCENT_ORANGE, false, 1.0)
	PixelGlyphs.draw_chip(self, chip_rect.position + Vector2(2, 1), "fuel", chip_text, ScreenLayout.COLOR_ACCENT_ORANGE)


func _draw_selection_outline() -> void:
	if not is_interactive or selected_stage_id == 0:
		return
	var has_stage_rect := false
	var stage_rect := Rect2()
	for block in _blocks:
		if block["stage_id"] != selected_stage_id or block["kind"] == BlockKind.PAYLOAD:
			continue
		if block["kind"] == BlockKind.STAGE_TAG:
			continue
		var block_rect: Rect2 = block["rect"]
		stage_rect = stage_rect.merge(block_rect) if has_stage_rect else block_rect
		has_stage_rect = true
	if has_stage_rect:
		draw_rect(stage_rect.grow(2.0), ScreenLayout.COLOR_ACCENT_ORANGE, false, 2.0)


func _draw_text(baseline_position: Vector2, text: String, width_pixels: float, font_size_pixels: int, text_color: Color) -> void:
	if width_pixels <= 0.0:
		return
	draw_string(get_theme_default_font(), baseline_position, text, HORIZONTAL_ALIGNMENT_LEFT, width_pixels,
			font_size_pixels, text_color)


## A part name without its "(... class)" note, for the labels beside the stack.
static func short_part_name(part_name: String) -> String:
	return part_name.get_slice(" (", 0).strip_edges()


## A label beside a block on a dark strip, so that it reads on the light
## blueprint grid; cut with an ellipsis when it is too wide.
func _draw_label(block_rect: Rect2, label_text: String, label_color: Color) -> void:
	var label_width: float = _label_width_pixels(block_rect)
	if label_width <= 0.0:
		return
	var shown_text: String = PixelGlyphs.fit_to_width(label_text, label_width - 4.0, LABEL_FONT_SIZE_PIXELS)
	var strip_rect := Rect2(_label_left_pixels() - 2.0, roundf(block_rect.get_center().y - 5.0),
			PixelGlyphs.text_width(shown_text, LABEL_FONT_SIZE_PIXELS) + 4.0, 10.0)
	draw_rect(strip_rect, Color(ScreenLayout.COLOR_SPACE_BLACK, 0.75))
	PixelGlyphs.draw_text(self, strip_rect.position + Vector2(2.0, 0.0), shown_text, label_color, LABEL_FONT_SIZE_PIXELS)


func _label_position(block_rect: Rect2) -> Vector2:
	return Vector2(_label_left_pixels(), block_rect.get_center().y + 3.0)


func _label_left_pixels() -> float:
	return _stack_right_pixels() + LAMP_COLUMN_WIDTH_PIXELS + 2.0


func _label_width_pixels(_block_rect: Rect2) -> float:
	return size.x - _label_left_pixels() - 2.0


## 1 for the bottom stage, 2 for the one above it, and so on. 0 when unknown.
func _stage_number(stage_id: int) -> int:
	if _design == null:
		return 0
	for stage_index in _design.stages.size():
		if _design.stages[stage_index].stage_id == stage_id:
			return stage_index + 1
	return 0


func _block_index_at(local_position: Vector2) -> int:
	for block_index in _blocks.size():
		var block: Dictionary = _blocks[block_index]
		if block["kind"] == BlockKind.MISSING_TANK:
			continue
		var block_rect: Rect2 = block["rect"]
		if block_rect.has_point(local_position):
			return block_index
	return -1


func _gui_input(event: InputEvent) -> void:
	if not is_interactive:
		return
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var lamp_index_under_mouse: int = _lamp_index_at(motion_event.position)
		var block_index_under_mouse: int = -1 if lamp_index_under_mouse >= 0 else _block_index_at(motion_event.position)
		if block_index_under_mouse != _hovered_block_index or lamp_index_under_mouse != _hovered_lamp_index:
			_hovered_block_index = block_index_under_mouse
			_hovered_lamp_index = lamp_index_under_mouse
			queue_redraw()
	elif event is InputEventKey and not _lamp_spots.is_empty():
		var is_next: bool = event.is_action_pressed("ui_focus_next")
		var is_previous: bool = event.is_action_pressed("ui_focus_prev")
		if is_next or is_previous:
			if step_lamp_focus(1 if is_next else -1):
				accept_event()
		elif event.is_action_pressed("ui_accept") and _focused_lamp_index >= 0:
			accept_event()
			toggle_lamp_pin(_focused_lamp_index)
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_lamp_index: int = _lamp_index_at(button_event.position)
			if clicked_lamp_index >= 0:
				accept_event()
				toggle_lamp_pin(clicked_lamp_index)
				return
			var clicked_block_index: int = _block_index_at(button_event.position)
			if clicked_block_index >= 0:
				accept_event()
				_report_click(_blocks[clicked_block_index])


## Moves the keyboard focus one lamp on (step 1) or back (step -1). From no
## focus, back starts at the last lamp. Returns false when the focus leaves
## the lamps past either end, so that Tab moves on as usual.
func step_lamp_focus(step: int) -> bool:
	if _lamp_spots.is_empty():
		return false
	var next_index: int = _focused_lamp_index + step
	if _focused_lamp_index < 0:
		next_index = 0 if step > 0 else _lamp_spots.size() - 1
	if next_index < 0 or next_index >= _lamp_spots.size():
		_focused_lamp_index = -1
		queue_redraw()
		return false
	_focused_lamp_index = next_index
	queue_redraw()
	return true


## The index of the lamp with the keyboard focus, or -1.
func focused_lamp_index() -> int:
	return _focused_lamp_index


## Pins the sentence of this lamp, or unpins it when it is pinned already.
func toggle_lamp_pin(lamp_index: int) -> void:
	_pinned_lamp_index = -1 if _pinned_lamp_index == lamp_index else lamp_index
	queue_redraw()


## Shows the sentence of this lamp as if the mouse were over it; -1 for none.
## For the screenshot capture and for tests.
func hover_lamp(lamp_index: int) -> void:
	_hovered_lamp_index = lamp_index
	queue_redraw()


func _lamp_index_at(local_position: Vector2) -> int:
	for lamp_index in _lamp_spots.size():
		var lamp_rect: Rect2 = _lamp_spots[lamp_index]["rect"]
		if lamp_rect.grow(2.0).has_point(local_position):
			return lamp_index
	return -1


func _report_click(block: Dictionary) -> void:
	var stage_id: int = block["stage_id"]
	match block["kind"]:
		BlockKind.ENGINE:
			engine_clicked.emit(stage_id)
		BlockKind.TANK:
			tank_clicked.emit(stage_id)
		BlockKind.PAYLOAD:
			var payload_index: int = block["payload_index"]
			payload_clicked.emit(payload_index)
		BlockKind.STAGE_TAG:
			stage_tag_clicked.emit(stage_id)


func _on_mouse_exited() -> void:
	if _hovered_block_index != -1 or _hovered_lamp_index != -1:
		_hovered_block_index = -1
		_hovered_lamp_index = -1
		queue_redraw()
