class_name ZoomTransition
extends RefCounted
## The animated move between the planning overview and a detail screen.
##
## The detail screen is a full-screen Control. Zooming in starts it shrunk onto
## the monitor it belongs to and grows it until it fills the screen, while the
## overview fades out. Zooming out plays the same move backwards.
## Static functions only; it keeps no state.

const DEFAULT_DURATION_SECONDS := 0.35


## Position and scale that make a full-screen Control cover exactly monitor_rect.
static func scale_on_monitor(monitor_rect: Rect2) -> Vector2:
	return monitor_rect.size / ScreenLayout.SCREEN_SIZE


## Grows detail_screen from monitor_rect to the full screen and fades overview
## out. Returns the running Tween, or null when duration_seconds is zero or
## less and the end state was applied at once.
static func zoom_in(
		detail_screen: Control,
		overview: Control,
		monitor_rect: Rect2,
		duration_seconds: float) -> Tween:
	detail_screen.pivot_offset = Vector2.ZERO
	detail_screen.position = monitor_rect.position
	detail_screen.scale = scale_on_monitor(monitor_rect)
	detail_screen.show()
	overview.show()
	if duration_seconds <= 0.0:
		detail_screen.position = Vector2.ZERO
		detail_screen.scale = Vector2.ONE
		overview.modulate.a = 0.0
		overview.hide()
		return null

	var tween: Tween = detail_screen.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(detail_screen, "position", Vector2.ZERO, duration_seconds)
	tween.tween_property(detail_screen, "scale", Vector2.ONE, duration_seconds)
	tween.tween_property(overview, "modulate:a", 0.0, duration_seconds)
	tween.chain().tween_callback(overview.hide)
	return tween


## Shrinks detail_screen from the full screen back onto monitor_rect, fades
## overview in, and hides detail_screen at the end. Returns the running Tween,
## or null when duration_seconds is zero or less.
static func zoom_out(
		detail_screen: Control,
		overview: Control,
		monitor_rect: Rect2,
		duration_seconds: float) -> Tween:
	overview.show()
	if duration_seconds <= 0.0:
		overview.modulate.a = 1.0
		detail_screen.hide()
		detail_screen.position = Vector2.ZERO
		detail_screen.scale = Vector2.ONE
		return null

	var tween: Tween = detail_screen.create_tween()
	tween.set_parallel(true)
	tween.set_ease(Tween.EASE_OUT)
	tween.set_trans(Tween.TRANS_CUBIC)
	tween.tween_property(detail_screen, "position", monitor_rect.position, duration_seconds)
	tween.tween_property(detail_screen, "scale", scale_on_monitor(monitor_rect), duration_seconds)
	tween.tween_property(overview, "modulate:a", 1.0, duration_seconds)
	tween.chain().tween_callback(detail_screen.hide)
	return tween
