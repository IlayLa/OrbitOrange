extends SceneTree
## Rebuilds every part icon under res://assets/art/parts/ from the team's
## 64 x 64 sprites in res://design/construction/.
##
## The sprites fill only a small corner of their 64 x 64 canvas, each a
## different size (sun sensor 7 x 5 up to the Orion booster 16 x 37). This
## script cuts each sprite to its used pixels and centres it, unscaled, on one
## ICON_CANVAS_SIZE square, so every icon keeps the same pixel size. The game
## draws the icons in 20 x 20 slots (PartCard, PartDetailsPopup,
## RocketStackPreview): two icon pixels per game pixel, one per screen pixel in
## the default 2x window.
##
## The tanks have no drawing of their own, only the three material swatches
## (design/construction/materials). This script draws a simple tank silhouette
## and fills it with the swatch's pattern: large tanks (regulated) are taller
## and carry a pressure regulator on top, small tanks (blowdown) are short.
## A stand-in until the artist draws real tanks.
##
## Run: godot --headless --path . -s tools/build_part_icons.gd
## Then let Godot re-import (open the editor, or run with --import).

const ICON_CANVAS_SIZE := 40
const OUTPUT_FOLDER := "res://assets/art/parts/"
const SOURCE_FOLDER := "res://design/construction/"

## Output file (under OUTPUT_FOLDER) -> sprite (under SOURCE_FOLDER).
const SPRITE_ICONS := {
	"engines/engine_cold_gas.png": "engines/engine_coldgas.png",
	"engines/engine_solid_kick.png": "engines/engine_star37.png",
	"engines/engine_solid_basic.png": "engines/engine_star48.png",
	"engines/engine_liquid_small.png": "engines/engine_rutherford.png",
	"engines/engine_liquid_basic.png": "engines/engine_merlin.png",
	"engines/engine_solid_booster.png": "engines/engine_orion.png",
	"engines/engine_liquid_hydrogen.png": "engines/engine_RL10.png",
	"telemetry/telemetry_altimeter_basic.png": "telemetry/tele_altmeter.png",
	"telemetry/telemetry_altimeter_precise.png": "telemetry/tele_betteraltmeter.png",
	"telemetry/telemetry_attitude_sun_sensor.png": "telemetry/tele_sunsensor.png",
	"telemetry/telemetry_attitude_star_tracker.png": "telemetry/tele_startracker.png",
	"telemetry/telemetry_fuel_gauge.png": "telemetry/tele_fuel.png",
	"telemetry/telemetry_computer_basic.png": "telemetry/tele_computer.png",
	"telemetry/telemetry_computer_hardened.png": "telemetry/tele_bettercomputer.png",
	"telemetry/telemetry_radar_basic.png": "telemetry/tele_radar.png",
	"telemetry/telemetry_radar_standard.png": "telemetry/tele_radar.png",
	"telemetry/telemetry_radar_advanced.png": "telemetry/tele_radar.png",
	"science/science_camera_basic.png": "science/science_camera.png",
	"science/science_camera_high_resolution.png": "science/science_bettercamera.png",
	"science/science_magnetometer.png": "science/science_magnetometer.png",
	"science/science_atmosphere_probe.png": "science/science_atmoprobe.png",
	"science/science_imaging_radar.png": "science/science_radar.png",
}

## Output file -> [material swatch, is_large_regulated_tank].
const TANK_ICONS := {
	"tanks/tank_aluminium_basic.png": ["materials/materials_aluminum.png", true],
	"tanks/tank_aluminium_blowdown.png": ["materials/materials_aluminum.png", false],
	"tanks/tank_aluminium_lithium_regulated.png": ["materials/materials_Al-Li.png", true],
	"tanks/tank_aluminium_lithium_blowdown.png": ["materials/materials_Al-Li.png", false],
	"tanks/tank_composite_regulated.png": ["materials/materials_carbon.png", true],
	"tanks/tank_composite_blowdown.png": ["materials/materials_carbon.png", false],
}

## The swatches are a 12 x 8 slanted plate; this part of it (relative to its
## used rect) is pattern only, without the shaded left and bottom edges.
const SWATCH_PATTERN_RECT := Rect2i(3, 0, 7, 7)
## The shaded edge colour of the swatch.
const SWATCH_SHADE_PIXEL := Vector2i(0, 0)

const TANK_WIDTH := 18
const LARGE_TANK_HEIGHT := 32
const SMALL_TANK_HEIGHT := 22
## Rows rounded off at the top and at the bottom of the tank.
const TANK_DOME_ROWS := 3
const TANK_OUTLINE_COLOR := Color("4a5260")
const REGULATOR_COLOR := Color("8a8c92")


func _init() -> void:
	var failed_count := 0
	for output_file in SPRITE_ICONS:
		var source := _load(SOURCE_FOLDER + SPRITE_ICONS[output_file])
		if source == null or not _save(_centred_on_canvas(source.get_region(source.get_used_rect())), output_file):
			failed_count += 1
	for output_file in TANK_ICONS:
		var swatch := _load(SOURCE_FOLDER + TANK_ICONS[output_file][0])
		if swatch == null or not _save(_centred_on_canvas(_tank(swatch, TANK_ICONS[output_file][1])), output_file):
			failed_count += 1
	print("Part icons rebuilt, %d failed." % failed_count)
	quit(1 if failed_count > 0 else 0)


func _load(resource_path: String) -> Image:
	var image := Image.load_from_file(ProjectSettings.globalize_path(resource_path))
	if image == null or image.is_empty():
		push_error("Could not load %s" % resource_path)
		return null
	image.convert(Image.FORMAT_RGBA8)
	return image


func _save(image: Image, output_file: String) -> bool:
	var error := image.save_png(ProjectSettings.globalize_path(OUTPUT_FOLDER + output_file))
	if error != OK:
		push_error("Could not save %s (error %d)" % [output_file, error])
	return error == OK


## The art, unscaled, in the middle of a transparent ICON_CANVAS_SIZE square.
func _centred_on_canvas(art: Image) -> Image:
	if art.get_width() > ICON_CANVAS_SIZE or art.get_height() > ICON_CANVAS_SIZE:
		push_error("Art of %s is larger than the icon canvas" % art.get_size())
	var canvas := Image.create_empty(ICON_CANVAS_SIZE, ICON_CANVAS_SIZE, false, Image.FORMAT_RGBA8)
	var offset := (Vector2i(ICON_CANVAS_SIZE, ICON_CANVAS_SIZE) - art.get_size()) / 2
	canvas.blit_rect(art, Rect2i(Vector2i.ZERO, art.get_size()), offset)
	return canvas


## A tank: a cylinder with rounded ends, outlined, filled with the swatch's
## pattern, lit from the left. A large tank has a regulator on top.
func _tank(swatch: Image, is_large: bool) -> Image:
	var swatch_rect := swatch.get_used_rect()
	var pattern := swatch.get_region(Rect2i(swatch_rect.position + SWATCH_PATTERN_RECT.position, SWATCH_PATTERN_RECT.size))
	var shade_color := swatch.get_pixelv(swatch_rect.position + SWATCH_SHADE_PIXEL)
	var regulator_rows := 3 if is_large else 0
	var body_height := LARGE_TANK_HEIGHT if is_large else SMALL_TANK_HEIGHT
	var tank := Image.create_empty(TANK_WIDTH, body_height + regulator_rows, false, Image.FORMAT_RGBA8)

	if is_large:
		# A small valve block on a stem, in the middle of the top dome.
		var middle := TANK_WIDTH / 2
		tank.fill_rect(Rect2i(middle - 3, 0, 6, 2), REGULATOR_COLOR)
		tank.fill_rect(Rect2i(middle - 1, 2, 2, 1), TANK_OUTLINE_COLOR)

	for row in body_height:
		var inset := _dome_inset(row, body_height)
		var left := inset
		var right := TANK_WIDTH - 1 - inset
		for x in range(left, right + 1):
			var is_edge := not (_is_inside(x - 1, row, body_height) and _is_inside(x + 1, row, body_height)
					and _is_inside(x, row - 1, body_height) and _is_inside(x, row + 1, body_height))
			var color: Color
			if is_edge:
				color = TANK_OUTLINE_COLOR
			else:
				color = pattern.get_pixel(x % pattern.get_width(), row % pattern.get_height())
				if x == left + 2:
					color = color.lightened(0.35)
				elif x >= right - 2:
					color = shade_color
			tank.set_pixel(x, regulator_rows + row, color)
	return tank


func _is_inside(x: int, row: int, body_height: int) -> bool:
	var inset := _dome_inset(row, body_height)
	return x >= inset and x <= TANK_WIDTH - 1 - inset


## How many pixels row `row` of the tank body is pulled in on each side, for
## the rounded top and bottom.
func _dome_inset(row: int, body_height: int) -> int:
	if row < 0 or row >= body_height:
		return TANK_WIDTH
	var distance_from_end := mini(row, body_height - 1 - row)
	if distance_from_end >= TANK_DOME_ROWS:
		return 0
	return [4, 2, 1][distance_from_end]
