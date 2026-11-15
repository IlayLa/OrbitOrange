class_name ExecutionLayout
extends RefCounted
## Rectangles and colours of the EXECUTION screen, measured from Amit's
## mock-up res://design/execution_screen.png (128 x 80 pixels) and multiplied
## by ScreenLayout.MOCKUP_SCALE. All rectangles are in pixels of the 640 x 400
## canvas. They live here because ScreenLayout belongs to the integrator; a
## contract request in tasks/notes/T08.md asks to move them there.

## --- Background images (128 x 80, stretched to ScreenLayout.SCREEN_SIZE) ----
const BACKGROUND_PATH := "res://design/execution_screen.png"
## The same picture with the alarm lamp lit. Only the lamp is cut out of it.
const ALARM_BACKGROUND_PATH := "res://design/execution_screen_alarm.png"
## The lamp inside the two background images, in mock-up pixels.
const LAMP_REGION_IN_MOCKUP := Rect2(55, 3, 11, 10)

## --- Mock-up panels (outer rectangle including the one-pixel grey frame) ----
const ALARM_LAMP_RECT := Rect2(275, 15, 55, 50)
const CLOCK_SCREEN := Rect2(40, 75, 180, 45)
const OBJECTIVES_SCREEN := Rect2(40, 135, 180, 240)
const RADAR_SCREEN := Rect2(325, 145, 170, 135)
const ANGLES_SCREEN := Rect2(515, 110, 105, 80)
const ALTITUDE_SCREEN := Rect2(290, 290, 105, 40)
const DELTA_V_SCREEN := Rect2(290, 340, 105, 40)
const ACCELERATION_SCREEN := Rect2(450, 295, 115, 90)
## Width of the grey frame drawn around every mock-up panel.
const PANEL_FRAME_PIXELS := 5

## Flat bezel over the unused gauge cutout baked into the mock-up.
const BEZEL_FILL_RECT := Rect2(300, 95, 105, 40)

## --- Radar scope inside RADAR_SCREEN ------------------------------------------
## Centre of the green rings and the radius of the outermost ring, relative to
## the top-left corner of RADAR_SCREEN.
const RADAR_CENTER_IN_SCREEN := Vector2(85, 67)
const RADAR_OUTER_RING_RADIUS_PIXELS := 60.0

## --- Controls the mock-up has no place for (on empty bezel; flagged) --------
const TIME_CONTROLS_RECT := Rect2(40, 42, 230, 26)
## Alarm texts and the alert message, right of the lamp. Stops before
## ScreenLayout.CONSOLE_SWITCH_RECT, which belongs to the console shell.
const ALARM_TEXT_RECT := Rect2(335, 12, 180, 80)
const SELF_DESTRUCT_BUTTON_RECT := Rect2(574, 348, 60, 42)
const SELF_DESTRUCT_MESSAGE_RECT := Rect2(330, 292, 240, 48)

## --- Colours taken from the execution mock-up ---------------------------------
const COLOR_BEZEL := Color("928667")
const COLOR_SCREEN_DARK := Color("3d3d3d")
const COLOR_SCREEN_LIGHT := Color("e1e1e1")
const COLOR_RADAR_RING_GREEN := Color("5cc616")
const COLOR_RADAR_SWEEP_GREEN := Color("65ff00")
const COLOR_LAMP_RED := Color("ff2400")


## Returns the part of a mock-up panel inside its grey frame, in pixels.
static func inside_frame(panel_rect: Rect2) -> Rect2:
	return panel_rect.grow(-PANEL_FRAME_PIXELS)
