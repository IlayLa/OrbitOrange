class_name OrbitSchematic
extends OrbitView
## A small orbit diagram for the mission screens (design/minimize_text_walls_options.md,
## Option 2): the body, the target ring with its tolerance halo, the science
## band in low-alpha blue, hazard belts as a 2 x 2 red and black checker, and
## altitude ticks with their real kilometre values. On the final screen it
## also draws the achieved orbit in solid white over the target, dashed green,
## and labels the miss ("+42km").
##
## Honest geometry: it uses OrbitView's display mapping, so altitude is
## stretched; the diagram then says so with an "ALT ×N" tag (N = how much more
## a kilometre of altitude is drawn than a kilometre of body radius). The
## achieved orbit is drawn from its real semi-major axis and eccentricity, and
## "e≈0" is written when the eccentricity is at most CIRCULAR_ECCENTRICITY.
## Bands and halos are never thinner than 2 pixels.

enum Mode { MISSION, RESULT }

const CIRCULAR_ECCENTRICITY := 0.05
const MINIMUM_BAND_WIDTH_PIXELS := 2.0
const SMALLEST_BODY_RADIUS_PIXELS := 10.0
const LARGEST_BODY_RADIUS_PIXELS := 26.0
const EDGE_MARGIN_PIXELS := 3.0
const DASH_ON_PIXELS := 3.0
const DASH_OFF_PIXELS := 3.0
const TICK_LABEL_SPACING_PIXELS := 9.0
## Free space kept right of the "ALT" tag, so a tick label never reads as part of it.
const TAG_CLEARANCE_PIXELS := 4.0
const ORBIT_SAMPLE_COUNT := 120
## A hazard belt whose outer edge is within this many times the mission's
## highest altitude is fitted into the diagram.
const HAZARD_FIT_FACTOR := 1.5
const COLOR_SCIENCE_BAND := Color(0.255, 0.443, 0.769, 0.5)
const COLOR_TARGET_HALO := Color(0.36, 0.76, 0.24, 0.3)
const COLOR_RING := Color(0.745, 0.827, 0.98, 0.35)
const COLOR_HAZARD := Color("e23a1a")
const COLOR_BODY_OUTLINE := Color("bed3fa")
## The body: a muted ocean blue between the monitor blue and the panel blue
## of the mock-ups, so it does not glare beside the pixel art.
const COLOR_BODY := Color("35609c")
## The achieved orbit: white, so it never sits orange-on-red over a hazard
## belt and reads for colour-blind players.
const COLOR_ACHIEVED_ORBIT := Color("ffffff")

var mode: Mode = Mode.MISSION
## How many times more a kilometre of altitude is drawn than a kilometre of
## the body's radius. 1 means true scale.
var altitude_stretch_factor: float = 1.0

var _schematic_mission: Dictionary = {}
var _science: Dictionary = {}
var _achieved_elements: OrbitElements
var _center: Vector2 = Vector2.ZERO


## OrbitView rescales from the mission's display entry when resized; the
## schematic fits its own scale to the altitudes it shows instead.
func _resize_display() -> void:
	if not _schematic_mission.is_empty():
		_fit_scale()
	queue_redraw()


## Shows a mission's target, the chosen science band (or the first one when
## science is empty) and its hazard belts.
func show_mission(mission: Dictionary, science: Dictionary = {}) -> void:
	mode = Mode.MISSION
	_schematic_mission = mission
	_science = science
	if _science.is_empty() and not mission.get("science_missions", []).is_empty():
		_science = mission["science_missions"][0]
	_achieved_elements = null
	_fit_scale()
	queue_redraw()


## Shows the achieved orbit over the target. achieved_elements is null when no
## closed orbit was reached.
func show_result(mission: Dictionary, achieved_elements: OrbitElements, science: Dictionary = {}) -> void:
	mode = Mode.RESULT
	_schematic_mission = mission
	_science = science
	_achieved_elements = achieved_elements
	if _achieved_elements != null and (_achieved_elements.is_open or _achieved_elements.semi_major_axis_meters <= 0.0):
		_achieved_elements = null
	_fit_scale()
	queue_redraw()


## The achieved mean altitude (from the semi-major axis, as Scoring uses)
## minus the target altitude, in kilometres. NAN without an achieved orbit.
func altitude_miss_kilometers() -> float:
	if _achieved_elements == null or _schematic_mission.is_empty():
		return NAN
	var body_radius_meters: float = GameData.body(_schematic_mission.get("body_id", "")).get("radius_meters", 0.0)
	var achieved_altitude_kilometers: float = (_achieved_elements.semi_major_axis_meters - body_radius_meters) / 1000.0
	return achieved_altitude_kilometers - float(_schematic_mission.get("target", {}).get("altitude_kilometers", 0.0))


## The "ALT ×N" tag text.
func stretch_tag_text() -> String:
	if altitude_stretch_factor <= 1.05:
		return "ALT to scale"
	return "ALT ×%d not to scale" % roundi(altitude_stretch_factor)


## True when a hazard belt starts beyond the edge of the diagram, so it is
## not drawn and its legend says so.
func is_beyond_diagram(zone: Dictionary) -> bool:
	var edge_radius_pixels: float = minf(size.x, size.y) * 0.5
	return drawn_radius_pixels(float(zone.get("inner_altitude_kilometers", 0.0))) > edge_radius_pixels


## Drawn radius of an altitude, in pixels from the body's centre.
func drawn_radius_pixels(altitude_kilometers: float) -> float:
	return maxf(1.0, body_radius_pixels + pixels_per_kilometer * altitude_kilometers)


func _fit_scale() -> void:
	var body: Dictionary = GameData.body(_schematic_mission.get("body_id", "earth"))
	var highest_altitude_kilometers := 1.0
	var target: Dictionary = _schematic_mission.get("target", {})
	highest_altitude_kilometers = maxf(highest_altitude_kilometers,
			float(target.get("altitude_kilometers", 0.0)) + float(target.get("altitude_tolerance_kilometers", 0.0)))
	for ring_altitude_kilometers in _schematic_mission.get("display", {}).get("altitude_ring_kilometers", []):
		highest_altitude_kilometers = maxf(highest_altitude_kilometers, float(ring_altitude_kilometers))
	if not _science.is_empty():
		highest_altitude_kilometers = maxf(highest_altitude_kilometers,
				float(_science.get("zone", {}).get("outer_altitude_kilometers", 0.0)))
	# A hazard belt near the mission widens the diagram; one far beyond it
	# (for example "everything above 2000 km") is listed as off the diagram.
	var mission_altitude_kilometers: float = highest_altitude_kilometers
	for zone: Dictionary in _hazard_zones():
		var outer_altitude_kilometers: float = zone.get("outer_altitude_kilometers", 0.0)
		if outer_altitude_kilometers <= mission_altitude_kilometers * HAZARD_FIT_FACTOR:
			highest_altitude_kilometers = maxf(highest_altitude_kilometers, outer_altitude_kilometers)
	if _achieved_elements != null:
		var achieved_apoapsis_kilometers: float = (_achieved_elements.apoapsis_radius_meters - float(body.get("radius_meters", 0.0))) / 1000.0
		if is_finite(achieved_apoapsis_kilometers):
			# A wild orbit may leave the diagram; the target stays readable.
			highest_altitude_kilometers = maxf(highest_altitude_kilometers, minf(achieved_apoapsis_kilometers, 2.0 * highest_altitude_kilometers))
	var half_extent_pixels: float = minf(size.x, size.y) * 0.5 - EDGE_MARGIN_PIXELS
	var new_body_radius_pixels: float = roundf(clampf(half_extent_pixels * 0.25, SMALLEST_BODY_RADIUS_PIXELS, LARGEST_BODY_RADIUS_PIXELS))
	var new_pixels_per_kilometer: float = maxf(0.0001, (half_extent_pixels - new_body_radius_pixels) / (highest_altitude_kilometers * 1.04))
	# Set directly: OrbitView.configure would rescale from the mission's display.
	_body = body
	body_radius_pixels = new_body_radius_pixels
	pixels_per_kilometer = new_pixels_per_kilometer
	var body_radius_kilometers: float = float(body.get("radius_meters", 1000.0)) / 1000.0
	altitude_stretch_factor = new_pixels_per_kilometer / (new_body_radius_pixels / body_radius_kilometers)


func _hazard_zones() -> Array:
	return _schematic_mission.get("hazard_zones", [])


func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), ScreenLayout.COLOR_SPACE_BLACK)
	if _schematic_mission.is_empty():
		return
	_center = (size * 0.5).floor()
	for zone: Dictionary in _hazard_zones():
		if is_beyond_diagram(zone):
			continue
		_draw_hazard_belt(float(zone.get("inner_altitude_kilometers", 0.0)), float(zone.get("outer_altitude_kilometers", 0.0)))
	if not _science.is_empty():
		var science_zone: Dictionary = _science.get("zone", {})
		_draw_band(float(science_zone.get("inner_altitude_kilometers", 0.0)), float(science_zone.get("outer_altitude_kilometers", 0.0)), COLOR_SCIENCE_BAND)

	var ring_altitudes: Array = _schematic_mission.get("display", {}).get("altitude_ring_kilometers", [])
	for ring_altitude_kilometers in ring_altitudes:
		draw_arc(_center, drawn_radius_pixels(float(ring_altitude_kilometers)), 0.0, TAU, 96, COLOR_RING, 1.0)

	var target: Dictionary = _schematic_mission.get("target", {})
	var target_altitude_kilometers: float = target.get("altitude_kilometers", 0.0)
	var tolerance_kilometers: float = target.get("altitude_tolerance_kilometers", 0.0)
	_draw_band(target_altitude_kilometers - tolerance_kilometers, target_altitude_kilometers + tolerance_kilometers, COLOR_TARGET_HALO)
	var target_radius_pixels: float = drawn_radius_pixels(target_altitude_kilometers)
	if mode == Mode.RESULT:
		_draw_dashed_circle(target_radius_pixels, PixelGlyphs.COLOR_GOOD_GREEN)
	else:
		draw_arc(_center, target_radius_pixels, 0.0, TAU, 128, PixelGlyphs.COLOR_GOOD_GREEN, 1.0)

	draw_circle(_center, body_radius_pixels, COLOR_BODY)
	draw_arc(_center, body_radius_pixels, 0.0, TAU, 64, COLOR_BODY_OUTLINE, 1.0)

	if mode == Mode.RESULT and _achieved_elements != null:
		_draw_achieved_orbit()

	var tag_rect: Rect2 = _draw_plated_text(Vector2(3, 1), stretch_tag_text(), PixelGlyphs.COLOR_MUTED_TEXT)
	_draw_tick_labels(ring_altitudes, tag_rect)
	_draw_eccentricity_tag(target)


func _draw_band(inner_altitude_kilometers: float, outer_altitude_kilometers: float, band_color: Color) -> void:
	var inner_radius_pixels: float = drawn_radius_pixels(inner_altitude_kilometers)
	var outer_radius_pixels: float = drawn_radius_pixels(outer_altitude_kilometers)
	var width_pixels: float = maxf(MINIMUM_BAND_WIDTH_PIXELS, outer_radius_pixels - inner_radius_pixels)
	draw_arc(_center, (inner_radius_pixels + outer_radius_pixels) * 0.5, 0.0, TAU, 128, band_color, width_pixels)


## A 2 x 2 pixel red and black checker inside the annulus. Hatching would alias at 1x.
func _draw_hazard_belt(inner_altitude_kilometers: float, outer_altitude_kilometers: float) -> void:
	var inner_radius_pixels: float = drawn_radius_pixels(inner_altitude_kilometers)
	var outer_radius_pixels: float = maxf(drawn_radius_pixels(outer_altitude_kilometers), inner_radius_pixels + MINIMUM_BAND_WIDTH_PIXELS * 2.0)
	# Cells beyond the corners are never seen.
	outer_radius_pixels = minf(outer_radius_pixels, size.length() * 0.5 + 2.0)
	if inner_radius_pixels >= outer_radius_pixels:
		return
	var cell_count: int = ceili(outer_radius_pixels / 2.0) + 1
	for cell_y in range(-cell_count, cell_count):
		for cell_x in range(-cell_count, cell_count):
			if (cell_x + cell_y) % 2 != 0:
				continue
			var cell_center := Vector2(cell_x * 2 + 1, cell_y * 2 + 1)
			var distance_pixels: float = cell_center.length()
			if distance_pixels < inner_radius_pixels or distance_pixels > outer_radius_pixels:
				continue
			var cell_rect := Rect2(_center + Vector2(cell_x * 2, cell_y * 2), Vector2(2, 2))
			if Rect2(Vector2.ZERO, size).encloses(cell_rect):
				draw_rect(cell_rect, COLOR_HAZARD)


func _draw_dashed_circle(radius_pixels: float, line_color: Color) -> void:
	var circumference_pixels: float = TAU * radius_pixels
	var dash_count: int = maxi(8, floori(circumference_pixels / (DASH_ON_PIXELS + DASH_OFF_PIXELS)))
	var dash_angle_radians: float = TAU / dash_count
	var on_fraction: float = DASH_ON_PIXELS / (DASH_ON_PIXELS + DASH_OFF_PIXELS)
	for dash_index in dash_count:
		var start_angle: float = dash_index * dash_angle_radians
		draw_arc(_center, radius_pixels, start_angle, start_angle + dash_angle_radians * on_fraction, 3, line_color, 1.0)


## The real ellipse (semi-major axis, eccentricity, argument of periapsis)
## through the display mapping.
func _draw_achieved_orbit() -> void:
	var body_radius_meters: float = _body.get("radius_meters", 1.0)
	var semi_major_axis_meters: float = _achieved_elements.semi_major_axis_meters
	var eccentricity: float = clampf(_achieved_elements.eccentricity, 0.0, 0.99)
	var direction_sign: float = -1.0 if _achieved_elements.is_clockwise else 1.0
	var points := PackedVector2Array()
	for sample_index in ORBIT_SAMPLE_COUNT + 1:
		var true_anomaly_radians: float = TAU * sample_index / ORBIT_SAMPLE_COUNT
		var radius_meters: float = semi_major_axis_meters * (1.0 - eccentricity * eccentricity) / (1.0 + eccentricity * cos(true_anomaly_radians))
		var polar_angle_radians: float = direction_sign * (_achieved_elements.argument_of_periapsis_radians + true_anomaly_radians)
		var drawn_pixels: float = drawn_radius_pixels((radius_meters - body_radius_meters) / 1000.0)
		points.append(_center + Vector2(cos(polar_angle_radians), -sin(polar_angle_radians)) * drawn_pixels)
	draw_polyline(points, COLOR_ACHIEVED_ORBIT, 2.0)


## Real kilometre values at the rings, stacked upward from the body's top on
## dark plates. A label too close to the one below it on the right goes to
## the left of the tick; one with no room on either side, or under the
## "ALT" tag (tag_rect), is skipped.
func _draw_tick_labels(ring_altitudes: Array, tag_rect: Rect2) -> void:
	# The top of the last label on the right and on the left of the ticks.
	var previous_label_tops: Array[float] = [INF, INF]
	var sorted_altitudes: Array = ring_altitudes.duplicate()
	sorted_altitudes.sort()
	for ring_altitude_kilometers in sorted_altitudes:
		var tick_y: float = roundf(_center.y - drawn_radius_pixels(float(ring_altitude_kilometers)))
		if tick_y < 0.0:
			continue
		draw_line(Vector2(_center.x - 2, tick_y), Vector2(_center.x + 2, tick_y), COLOR_BODY_OUTLINE, 1.0)
		var label_top: float = maxf(0.0, tick_y - 4.0)
		var label_text := NumberFormat.kilometers(float(ring_altitude_kilometers))
		var label_width: float = PixelGlyphs.text_width(label_text)
		for side_index in 2:
			var label_left: float = _center.x + 5.0 if side_index == 0 else _center.x - 5.0 - label_width
			var plate_rect := Rect2(Vector2(label_left - 1.0, label_top), Vector2(label_width + 2.0, PixelGlyphs.LINE_HEIGHT_PIXELS))
			if previous_label_tops[side_index] - label_top < TICK_LABEL_SPACING_PIXELS or plate_rect.intersects(tag_rect.grow_individual(0, 0, TAG_CLEARANCE_PIXELS, 0)):
				continue
			_draw_plated_text(Vector2(label_left, label_top), label_text, COLOR_BODY_OUTLINE)
			previous_label_tops[side_index] = label_top
			break


## Text on a dark plate one pixel wider than the text; returns the plate.
func _draw_plated_text(top_left: Vector2, text: String, text_color: Color) -> Rect2:
	var plate_rect := Rect2(top_left - Vector2(1, 0), Vector2(PixelGlyphs.text_width(text) + 2.0, PixelGlyphs.LINE_HEIGHT_PIXELS))
	draw_rect(plate_rect, COLOR_LABEL_PLATE)
	PixelGlyphs.draw_text(self, top_left, text, text_color)
	return plate_rect


func _draw_eccentricity_tag(target: Dictionary) -> void:
	var eccentricity: float = target.get("eccentricity", 0.0)
	var tag_color: Color = PixelGlyphs.COLOR_GOOD_GREEN
	if mode == Mode.RESULT:
		if _achieved_elements == null:
			return
		eccentricity = _achieved_elements.eccentricity
		tag_color = COLOR_ACHIEVED_ORBIT
	var tag_text := "e≈0" if eccentricity <= CIRCULAR_ECCENTRICITY else "e=%.2f" % eccentricity
	_draw_plated_text(Vector2(3, size.y - 10), tag_text, tag_color)
