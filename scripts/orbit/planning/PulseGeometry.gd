class_name PulseGeometry
extends RefCounted
## Drawing/picking conversions for the locally stretched display and V/B arrows,
## and the aiming visuals every burn editor shares (orbit planning, emergency).

## A press that moves less than this is a click, not a slingshot pull.
const SLINGSHOT_THRESHOLD_PIXELS := 6.0
## Press distance that picks an arrow tip, and a burn's base point.
const ARROW_TIP_PICK_PIXELS := 8.0
const ANCHOR_PICK_PIXELS := 9.0
## Under the cursor: the part a press would grab.
const COLOR_HOVER := Color("#8be7e6")
const COLOR_PULL_LINE := Color(0.9, 0.9, 1.0, 0.75)
const COLOR_CAPTION := Color("#e4eaf0")
const COLOR_SELECTED_CAPTION := Color("#0c1925")
## Same convention and wording in every angle field.
const DIRECTION_HELP_TEXT := "Burn direction. 0° along motion · +90° outward"


## Which part of a burn a press grabs: "arrow", "anchor", or "" for neither.
## When both are in reach the nearer wins, so a short arrow cannot hide its base.
static func pick_part(press_pixels: Vector2, anchor_pixels: Vector2, tip_pixels: Vector2) -> String:
	var tip_distance_pixels: float = press_pixels.distance_to(tip_pixels)
	var anchor_distance_pixels: float = press_pixels.distance_to(anchor_pixels)
	if tip_distance_pixels <= ARROW_TIP_PICK_PIXELS and tip_distance_pixels < anchor_distance_pixels:
		return "arrow"
	if anchor_distance_pixels <= ANCHOR_PICK_PIXELS:
		return "anchor"
	if tip_distance_pixels <= ARROW_TIP_PICK_PIXELS:
		return "arrow"
	return ""


## The burn direction a drag gives: a slingshot pull mirrors through the anchor
## (pull back, burn forward); grabbing the tip points it at the cursor.
static func dragged_direction(anchor_pixels: Vector2, cursor_pixels: Vector2, is_slingshot: bool) -> Vector2:
	return anchor_pixels - cursor_pixels if is_slingshot else cursor_pixels - anchor_pixels


## A burn arrow; selected arrows are drawn thicker.
static func draw_arrow(canvas: CanvasItem, anchor_pixels: Vector2, tip_pixels: Vector2, color: Color, is_selected: bool) -> void:
	var width_pixels: float = 3.0 if is_selected else 2.0
	canvas.draw_line(anchor_pixels, tip_pixels, color, width_pixels, true)
	var direction: Vector2 = (tip_pixels - anchor_pixels).normalized()
	canvas.draw_line(tip_pixels, tip_pixels - direction.rotated(0.5) * 6.0, color, width_pixels, true)
	canvas.draw_line(tip_pixels, tip_pixels - direction.rotated(-0.5) * 6.0, color, width_pixels, true)
	canvas.draw_circle(anchor_pixels, 4.0, color)
	if is_selected:
		canvas.draw_arc(anchor_pixels, 8.0, 0.0, TAU, 24, Color.WHITE, 2.0, true)


## The cyan ring on the part a press would grab.
static func draw_hover_ring(canvas: CanvasItem, position_pixels: Vector2) -> void:
	canvas.draw_arc(position_pixels, 8.0, 0.0, TAU, 24, COLOR_HOVER, 1.5, true)


## While aiming: the slingshot's pull line (if any) and the burn in numbers by the cursor.
static func draw_aim_feedback(canvas: Control, anchor_pixels: Vector2, is_slingshot: bool,
		delta_v_meters_per_second: float, angle_degrees: float, is_solid: bool) -> void:
	var cursor_pixels: Vector2 = canvas.get_local_mouse_position()
	if is_slingshot:
		canvas.draw_dashed_line(anchor_pixels, cursor_pixels, COLOR_PULL_LINE, 1.0, 2.0)
	var caption: String = "%.0f°" % angle_degrees
	if not is_solid:
		caption = "%.0f m/s · %s" % [delta_v_meters_per_second, caption]
	var font: Font = ThemeDB.fallback_font
	var font_size_pixels := 10
	var text_size: Vector2 = font.get_string_size(caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size_pixels)
	var ascent_pixels: float = font.get_ascent(font_size_pixels)
	var baseline_pixels: Vector2 = cursor_pixels + Vector2(10, -8)
	baseline_pixels.x = minf(baseline_pixels.x, canvas.size.x - text_size.x - 3.0)
	baseline_pixels.y = maxf(baseline_pixels.y, ascent_pixels + 2.0)
	canvas.draw_rect(Rect2(baseline_pixels - Vector2(2, ascent_pixels + 1), text_size + Vector2(4, 2)), OrbitView.COLOR_LABEL_PLATE)
	canvas.draw_string(font, baseline_pixels, caption, HORIZONTAL_ALIGNMENT_LEFT, -1.0, font_size_pixels, COLOR_CAPTION)


## A normalized control-local screen direction for a pulse at its pre-burn state.
static func arrow_direction(view: OrbitView, state: OrbitState, pulse: Pulse) -> Vector2:
	if state == null or state.speed_meters_per_second() <= 0.0:
		return Vector2.RIGHT
	var along := Vector2(state.velocity_x_meters_per_second, state.velocity_y_meters_per_second).normalized()
	var motion_sign: float = -1.0 if Kepler.signed_angular_momentum(state) < 0.0 else 1.0
	var outward := Vector2(along.y, -along.x) * motion_sign
	var world_direction: Vector2 = along * pulse.delta_v_along_velocity_meters_per_second + outward * pulse.delta_v_outward_meters_per_second
	return _project(view, state, world_direction, false).normalized()


## Unit V/B components corresponding to a dragged screen direction.
static func components_from_direction(view: OrbitView, state: OrbitState, direction_pixels: Vector2) -> Vector2:
	if state == null or state.speed_meters_per_second() <= 0.0:
		return Vector2.RIGHT
	var world_direction: Vector2 = _project(view, state, direction_pixels, true).normalized()
	var along := Vector2(state.velocity_x_meters_per_second, state.velocity_y_meters_per_second).normalized()
	var motion_sign: float = -1.0 if Kepler.signed_angular_momentum(state) < 0.0 else 1.0
	var outward := Vector2(along.y, -along.x) * motion_sign
	return Vector2(world_direction.dot(along), world_direction.dot(outward))


## Arrow length in pixels, with logarithmic magnitude compression and no fuel cap.
static func arrow_length_pixels(delta_v_meters_per_second: float) -> float:
	return 10.0 + 13.0 * log(1.0 + maxf(0.0, delta_v_meters_per_second) / 100.0)


## Requested delta-v in m/s corresponding to a dragged arrow length.
static func magnitude_from_length(length_pixels: float) -> float:
	return 100.0 * (exp(clampf((length_pixels - 10.0) / 13.0, 0.0, 50.0)) - 1.0)


static func _project(view: OrbitView, state: OrbitState, vector: Vector2, is_inverse: bool) -> Vector2:
	var radial := Vector2(state.position_x_meters / state.radius_meters(), state.position_y_meters / state.radius_meters())
	var tangent := Vector2(-radial.y, radial.x)
	var radius_pixels: float = view.world_to_screen(state.position_x_meters, state.position_y_meters).distance_to(view.size / 2.0)
	var radial_scale: float = view.pixels_per_kilometer / 1000.0
	var tangent_scale: float = maxf(0.000000001, radius_pixels / state.radius_meters())
	if is_inverse:
		var world_screen := Vector2(vector.x, -vector.y)
		return radial * (world_screen.dot(radial) / radial_scale) + tangent * (world_screen.dot(tangent) / tangent_scale)
	var transformed: Vector2 = radial * vector.dot(radial) * radial_scale + tangent * vector.dot(tangent) * tangent_scale
	return Vector2(transformed.x, -transformed.y)
