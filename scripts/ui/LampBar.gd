class_name LampBar
extends Control
## One row of warning lamps for a bezel: a summary such as "✖1 ▲2", then one
## lamp per sentence with the stage, pulse or rocket it is about ("S2", "P1").
## Hovering a lamp reports its sentence; clicking pins it until clicked again;
## Tab and Shift+Tab move the focus from lamp to lamp while the bar has focus.
## The bar only shows; the owner decides where the sentence is written.

## The sentence of the lamp under the mouse, pinned or focused; "" for none.
signal active_sentence_changed(sentence: String, severity: int)

const ROW_HEIGHT_PIXELS := 11.0
const CHIP_GAP_PIXELS := 6.0
const COLOR_BACKGROUND := Color(0, 0, 0, 0.55)
const COLOR_HIGHLIGHT := Color("bed3fa")

var _lamps: Array[Dictionary] = []
## Rectangles of the lamp chips, in the order of _lamps.
var _chip_rects: Array[Rect2] = []
var _hovered_index: int = -1
var _pinned_index: int = -1
var _focused_index: int = -1


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_ALL
	mouse_exited.connect(_on_mouse_exited)
	focus_exited.connect(_on_focus_exited)


## Shows these lamps (from WarningLamps.lamps_from_summary). Keeps a pinned
## lamp pinned when its sentence is still present.
func set_lamps(lamps: Array[Dictionary]) -> void:
	var pinned_sentence := ""
	if _pinned_index >= 0 and _pinned_index < _lamps.size():
		pinned_sentence = _lamps[_pinned_index]["sentence"]
	_lamps = lamps
	_hovered_index = -1
	_focused_index = -1
	_pinned_index = -1
	for lamp_index in _lamps.size():
		if _lamps[lamp_index]["sentence"] == pinned_sentence and not pinned_sentence.is_empty():
			_pinned_index = lamp_index
	_layout_chips()
	queue_redraw()
	_report_active_sentence()


## The index of the lamp whose sentence is shown, or -1.
func active_lamp_index() -> int:
	if _hovered_index >= 0:
		return _hovered_index
	if _focused_index >= 0:
		return _focused_index
	return _pinned_index


## Pins the lamp with this index, or unpins it when it is pinned already.
func toggle_pin(lamp_index: int) -> void:
	_pinned_index = -1 if _pinned_index == lamp_index else lamp_index
	queue_redraw()
	_report_active_sentence()


func _layout_chips() -> void:
	_chip_rects.clear()
	var next_left: float = _summary_width() + CHIP_GAP_PIXELS * 2.0
	for lamp in _lamps:
		var chip_width: float = PixelGlyphs.chip_width("lamp_ok", lamp["target_text"]) + 2.0
		_chip_rects.append(Rect2(next_left, 0, chip_width, ROW_HEIGHT_PIXELS))
		next_left += chip_width + CHIP_GAP_PIXELS


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
	for lamp_index in _lamps.size():
		var lamp: Dictionary = _lamps[lamp_index]
		var chip_rect: Rect2 = _chip_rects[lamp_index]
		if chip_rect.position.x > size.x:
			break
		var severity: int = lamp["severity"]
		var chip_top := Vector2(chip_rect.position.x + 1.0, row_top)
		PixelGlyphs.draw_chip(self, chip_top, PixelGlyphs.lamp_glyph_name(severity), lamp["target_text"],
				PixelGlyphs.lamp_color(severity))
		var frame_rect := Rect2(chip_rect.position.x - 1.0, row_top - 2.0, chip_rect.size.x + 2.0, ROW_HEIGHT_PIXELS + 2.0)
		if lamp_index == _pinned_index:
			draw_rect(frame_rect, ScreenLayout.COLOR_ACCENT_ORANGE, false, 1.0)
		elif lamp_index == active_index:
			draw_rect(frame_rect, COLOR_HIGHLIGHT, false, 1.0)


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
	elif event is InputEventKey and not _lamps.is_empty():
		var is_next: bool = event.is_action_pressed("ui_focus_next")
		var is_previous: bool = event.is_action_pressed("ui_focus_prev")
		if is_next or is_previous:
			var step := 1 if is_next else -1
			var next_index: int = _focused_index + step
			if next_index >= _lamps.size() or next_index < 0:
				# Past the last lamp, focus leaves the bar as usual.
				_focused_index = -1
				queue_redraw()
				_report_active_sentence()
				return
			_focused_index = next_index
			accept_event()
			queue_redraw()
			_report_active_sentence()
		elif event.is_action_pressed("ui_accept") and _focused_index >= 0:
			accept_event()
			toggle_pin(_focused_index)


func _chip_index_at(local_position: Vector2) -> int:
	for chip_index in _chip_rects.size():
		if _chip_rects[chip_index].grow(2.0).has_point(Vector2(local_position.x, _chip_rects[chip_index].get_center().y)) \
				and local_position.y >= 0.0 and local_position.y <= size.y:
			return chip_index
	return -1


func _report_active_sentence() -> void:
	var active_index: int = active_lamp_index()
	if active_index < 0 or active_index >= _lamps.size():
		active_sentence_changed.emit("", WarningLamps.Severity.OK)
		return
	active_sentence_changed.emit(_lamps[active_index]["sentence"], _lamps[active_index]["severity"])


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
