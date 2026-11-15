class_name LampBar
extends Control
## One row of warning lamps for a bezel: a summary such as "✖1 ▲2", then one
## lamp per sentence with the stage, pulse or rocket it is about ("S2", "P1").
## Lamps that do not fit the row are gathered in one "+N" chip, whose sentence
## lists the hidden ones.
## Hovering a chip reports its sentence; clicking pins it until clicked again;
## Tab and Shift+Tab move the focus from chip to chip while the bar has focus
## (Shift+Tab into the bar starts at the last chip); Enter pins.
## The bar only shows; the owner decides where the sentence is written.

## The sentence of the chip under the mouse, pinned or focused; "" for none.
signal active_sentence_changed(sentence: String, severity: int)

const ROW_HEIGHT_PIXELS := 11.0
const CHIP_GAP_PIXELS := 6.0
const COLOR_BACKGROUND := Color(0, 0, 0, 0.55)
const COLOR_HIGHLIGHT := Color("bed3fa")

var _lamps: Array[Dictionary] = []
## What is drawn after the summary: the lamps that fit, then, when some do
## not, one overflow entry ("target_text" "+N", the hidden sentences, the
## worst hidden severity). Hover, pins, focus and clicks all use these.
var _entries: Array[Dictionary] = []
## Rectangles of the entries, in the same order.
var _chip_rects: Array[Rect2] = []
var _hovered_index: int = -1
var _pinned_index: int = -1
var _focused_index: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(_on_mouse_exited)
	focus_exited.connect(_on_focus_exited)
	resized.connect(_on_resized)


## The hover help as a wrapped block, not the engine's single long line.
func _make_custom_tooltip(for_text: String) -> Object:
	return PixelTooltip.make(for_text)


## Shows these lamps (from WarningLamps.lamps_from_summary). A pinned or
## focused chip stays so while its sentence is still present.
func set_lamps(lamps: Array[Dictionary]) -> void:
	var pinned_sentence := _entry_sentence(_pinned_index)
	var focused_sentence := _entry_sentence(_focused_index)
	_lamps = lamps
	_layout_chips()
	_hovered_index = -1
	_pinned_index = _entry_index_of(pinned_sentence)
	_focused_index = _entry_index_of(focused_sentence)
	queue_redraw()
	_report_active_sentence()


## The chips after the summary, overflow chip included.
func entries() -> Array[Dictionary]:
	return _entries


## The index (in entries()) whose sentence is shown, or -1.
func active_lamp_index() -> int:
	if _hovered_index >= 0:
		return _hovered_index
	if _focused_index >= 0:
		return _focused_index
	return _pinned_index


## Pins the entry with this index, or unpins it when it is pinned already.
func toggle_pin(entry_index: int) -> void:
	if entry_index < 0 or entry_index >= _entries.size():
		return
	_pinned_index = -1 if _pinned_index == entry_index else entry_index
	queue_redraw()
	_report_active_sentence()


## Moves the keyboard focus one chip on (step 1) or back (step -1). From no
## focus, back starts at the last chip. Returns false when the focus leaves
## the bar (past either end).
func step_focus(step: int) -> bool:
	if _entries.is_empty():
		return false
	var next_index: int = _focused_index + step
	if _focused_index < 0:
		next_index = 0 if step > 0 else _entries.size() - 1
	if next_index < 0 or next_index >= _entries.size():
		_focused_index = -1
		queue_redraw()
		_report_active_sentence()
		return false
	_focused_index = next_index
	queue_redraw()
	_report_active_sentence()
	return true


func _entry_sentence(entry_index: int) -> String:
	if entry_index < 0 or entry_index >= _entries.size():
		return ""
	return _entries[entry_index]["sentence"]


func _entry_index_of(sentence: String) -> int:
	if sentence.is_empty():
		return -1
	for entry_index in _entries.size():
		if _entries[entry_index]["sentence"] == sentence:
			return entry_index
	return -1


func _chip_width(target_text: String) -> float:
	return PixelGlyphs.chip_width("lamp_ok", target_text) + 2.0


func _layout_chips() -> void:
	_entries.clear()
	_chip_rects.clear()
	var first_left: float = _summary_width() + CHIP_GAP_PIXELS * 2.0
	var row_right: float = size.x - 2.0
	var next_left: float = first_left
	for lamp_index in _lamps.size():
		var lamp: Dictionary = _lamps[lamp_index]
		var chip_width: float = _chip_width(lamp["target_text"])
		var hidden_count: int = _lamps.size() - lamp_index - 1
		# Room for this chip, and for the "+N" chip when more follow.
		var needed_right: float = next_left + chip_width
		if hidden_count > 0:
			needed_right += CHIP_GAP_PIXELS + _chip_width("+%d" % hidden_count)
		if needed_right > row_right and size.x > 0.0:
			_add_overflow_entry(lamp_index, next_left)
			return
		_entries.append(lamp)
		_chip_rects.append(Rect2(next_left, 0, chip_width, ROW_HEIGHT_PIXELS))
		next_left += chip_width + CHIP_GAP_PIXELS


func _add_overflow_entry(first_hidden_index: int, chip_left: float) -> void:
	var hidden_sentences: PackedStringArray = []
	var worst_severity: int = WarningLamps.Severity.OK
	for lamp_index in range(first_hidden_index, _lamps.size()):
		hidden_sentences.append("%s: %s" % [_lamps[lamp_index]["target_text"], _lamps[lamp_index]["sentence"]])
		worst_severity = maxi(worst_severity, _lamps[lamp_index]["severity"])
	var target_text := "+%d" % hidden_sentences.size()
	_entries.append({
		"severity": worst_severity,
		"sentence": " / ".join(hidden_sentences),
		"target_text": target_text,
		"is_overflow": true,
	})
	_chip_rects.append(Rect2(chip_left, 0, _chip_width(target_text), ROW_HEIGHT_PIXELS))


func _summary_width() -> float:
	var lamp_counts: Vector2i = WarningLamps.counts(_lamps)
	if lamp_counts == Vector2i.ZERO:
		return 2.0 + PixelGlyphs.chip_width("lamp_ok", "OK")
	var width := 2.0
	if lamp_counts.x > 0:
		width += PixelGlyphs.chip_width("lamp_blocking", str(lamp_counts.x)) + 4.0
	if lamp_counts.y > 0:
		width += PixelGlyphs.chip_width("lamp_warning", str(lamp_counts.y)) + 4.0
	return width


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_BACKGROUND)
	var lamp_counts: Vector2i = WarningLamps.counts(_lamps)
	var next_left := 2.0
	var row_top := floorf((size.y - ROW_HEIGHT_PIXELS) * 0.5) + 1.0
	if lamp_counts == Vector2i.ZERO:
		PixelGlyphs.draw_chip(self, Vector2(next_left, row_top), "lamp_ok", "OK", PixelGlyphs.COLOR_GOOD_GREEN)
	else:
		if lamp_counts.x > 0:
			next_left += PixelGlyphs.draw_chip(self, Vector2(next_left, row_top), "lamp_blocking",
					str(lamp_counts.x), ScreenLayout.COLOR_WARNING_RED) + 4.0
		if lamp_counts.y > 0:
			PixelGlyphs.draw_chip(self, Vector2(next_left, row_top), "lamp_warning",
					str(lamp_counts.y), PixelGlyphs.COLOR_AMBER)
	var separator_left: float = _summary_width() + CHIP_GAP_PIXELS
	if not _lamps.is_empty():
		draw_line(Vector2(separator_left, 1), Vector2(separator_left, size.y - 1), PixelGlyphs.COLOR_MUTED_TEXT, 1.0)

	var active_index: int = active_lamp_index()
	for entry_index in _entries.size():
		var entry: Dictionary = _entries[entry_index]
		var chip_rect: Rect2 = _chip_rects[entry_index]
		var severity: int = entry["severity"]
		var chip_top := Vector2(chip_rect.position.x + 1.0, row_top)
		if entry.get("is_overflow", false):
			# No lamp shape: the "+N" text says these are more lamps.
			PixelGlyphs.draw_text(self, chip_top, entry["target_text"], COLOR_HIGHLIGHT)
		else:
			PixelGlyphs.draw_chip(self, chip_top, PixelGlyphs.lamp_glyph_name(severity), entry["target_text"],
					PixelGlyphs.lamp_color(severity))
		var frame_rect := Rect2(chip_rect.position.x - 1.0, row_top - 2.0, chip_rect.size.x + 2.0, ROW_HEIGHT_PIXELS + 2.0)
		if entry_index == _pinned_index:
			draw_rect(frame_rect, ScreenLayout.COLOR_ACCENT_ORANGE, false, 1.0)
		elif entry_index == active_index:
			draw_rect(frame_rect, COLOR_HIGHLIGHT, false, 1.0)
		if entry_index == _focused_index and has_focus():
			draw_line(Vector2(frame_rect.position.x, frame_rect.end.y + 1.0), Vector2(frame_rect.end.x, frame_rect.end.y + 1.0), COLOR_HIGHLIGHT, 1.0)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion:
		var motion_event: InputEventMouseMotion = event
		var index_under_mouse: int = _chip_index_at(motion_event.position)
		if index_under_mouse != _hovered_index:
			_hovered_index = index_under_mouse
			queue_redraw()
			_report_active_sentence()
	elif event is InputEventMouseButton:
		var button_event: InputEventMouseButton = event
		if button_event.pressed and button_event.button_index == MOUSE_BUTTON_LEFT:
			var clicked_index: int = _chip_index_at(button_event.position)
			if clicked_index >= 0:
				accept_event()
				toggle_pin(clicked_index)
	elif event is InputEventKey and not _entries.is_empty():
		var is_next: bool = event.is_action_pressed("ui_focus_next")
		var is_previous: bool = event.is_action_pressed("ui_focus_prev")
		if is_next or is_previous:
			# Past either end, the event is left alone and focus leaves the bar.
			if step_focus(1 if is_next else -1):
				accept_event()
		elif event.is_action_pressed("ui_accept") and _focused_index >= 0:
			accept_event()
			toggle_pin(_focused_index)


func _chip_index_at(local_position: Vector2) -> int:
	if local_position.y < 0.0 or local_position.y > size.y:
		return -1
	for chip_index in _chip_rects.size():
		var chip_rect: Rect2 = _chip_rects[chip_index].grow(2.0)
		if local_position.x >= chip_rect.position.x and local_position.x <= chip_rect.end.x:
			return chip_index
	return -1


func _report_active_sentence() -> void:
	var active_index: int = active_lamp_index()
	if active_index < 0 or active_index >= _entries.size():
		active_sentence_changed.emit("", WarningLamps.Severity.OK)
		return
	active_sentence_changed.emit(_entries[active_index]["sentence"], _entries[active_index]["severity"])


func _on_resized() -> void:
	set_lamps(_lamps)


func _on_mouse_exited() -> void:
	if _hovered_index != -1:
		_hovered_index = -1
		queue_redraw()
		_report_active_sentence()


func _on_focus_exited() -> void:
	if _focused_index != -1:
		_focused_index = -1
		queue_redraw()
		_report_active_sentence()
