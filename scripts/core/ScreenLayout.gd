class_name ScreenLayout
extends RefCounted
## Sizes, rectangles and colours shared by every screen.
##
## The game is drawn on a 640 x 400 pixel canvas. That is exactly five times
## the 128 x 80 pixel mock-ups in res://design, so every rectangle below is a
## mock-up rectangle multiplied by MOCKUP_SCALE. All values are in pixels.
## Owned by the integrator: ask for a change in tasks/notes/ instead of editing.

const SCREEN_SIZE := Vector2(640, 400)
const MOCKUP_SCALE := 5

## --- Background images (128 x 80, stretch them to SCREEN_SIZE) -------------
const PLANNING_OVERVIEW_BACKGROUND_PATH := "res://design/planning_screen.png"
const ROCKET_DESIGN_BACKGROUND_PATH := "res://design/construction_screen.png"
const ORBIT_PLANNING_BACKGROUND_PATH := "res://design/orbit_screen.png"
const MISSION_SELECT_BACKGROUND_PATH := "res://design/mission_choice.png"
const LOGO_PATH := "res://design/LOGO.png"

## --- Present on every console screen ----------------------------------------
## The PLANNING / EXECUTION switch, drawn by Console. This corner is empty
## bezel in all three mock-ups. No other scene may draw here.
const CONSOLE_SWITCH_RECT := Rect2(520, 2, 118, 30)
## The "back to overview" button, drawn by PlanningConsole while zoomed in.
const BACK_BUTTON_RECT := Rect2(520, 34, 118, 22)

## --- Planning overview (planning_screen.png) --------------------------------
const OVERVIEW_ROCKET_MONITOR_SCREEN := Rect2(80, 95, 130, 215)
const OVERVIEW_PARTS_COLUMN := Rect2(235, 80, 70, 240)
const OVERVIEW_ORBIT_MONITOR_SCREEN := Rect2(350, 175, 245, 175)
## Cost, delta-v and weight chips, left to right.
const OVERVIEW_STAT_CHIP_SCREENS: Array[Rect2] = [
	Rect2(340, 105, 70, 40),
	Rect2(430, 105, 70, 40),
	Rect2(520, 105, 85, 40),
]
## Empty bezel above the monitors: free for the Launch button and messages.
const OVERVIEW_TOP_BEZEL := Rect2(65, 2, 450, 76)

## --- Rocket design screen (construction_screen.png) -------------------------
const ROCKET_DESIGN_PREVIEW_SCREEN := Rect2(75, 60, 220, 300)
const ROCKET_DESIGN_PART_LIST := Rect2(355, 50, 105, 320)
## Engine, tank, telemetry and science tabs, top to bottom. The mock-up labels
## them ENG, MAT, TEL and SCI.
const ROCKET_DESIGN_CATEGORY_TABS: Array[Rect2] = [
	Rect2(465, 50, 105, 55),
	Rect2(465, 110, 105, 50),
	Rect2(465, 165, 105, 50),
	Rect2(465, 220, 105, 50),
]
## The empty cell below the four tabs.
const ROCKET_DESIGN_FREE_CELL := Rect2(465, 275, 105, 95)

## --- Orbit planning screen (orbit_screen.png) -------------------------------
const ORBIT_PLANNING_VIEW_SCREEN := Rect2(40, 75, 465, 295)
const ORBIT_PLANNING_ENGINE_LIST := Rect2(535, 65, 85, 315)
## Cost, delta-v and weight chips, left to right. PlanningConsole draws the
## chips on every planning screen; the orbit planning scene leaves these empty.
const ORBIT_PLANNING_STAT_CHIP_SCREENS: Array[Rect2] = [
	Rect2(30, 10, 155, 40),
	Rect2(205, 10, 150, 40),
	Rect2(375, 10, 140, 40),
]

## --- Mission select (mission_choice.png) ------------------------------------
## Inside of the three white-framed panels: Mission, Science, Quests.
const MISSION_SELECT_PANEL_SCREENS: Array[Rect2] = [
	Rect2(30, 25, 185, 345),
	Rect2(230, 25, 180, 345),
	Rect2(425, 25, 185, 345),
]
## Each panel's title row: above the short white rule, as wide as the rule.
const MISSION_SELECT_TITLE_ROWS: Array[Rect2] = [
	Rect2(55, 25, 130, 35),
	Rect2(255, 25, 130, 35),
	Rect2(450, 25, 135, 35),
]
## The boxes below the titles, white frame included. The Mission panel has a
## box per mission card; Science one for the first card; Quests a short box
## for the penalty pips and, below it, one for the first quest card.
const MISSION_SELECT_MISSION_CARD_BOXES: Array[Rect2] = [
	Rect2(35, 70, 175, 55),
	Rect2(35, 130, 175, 55),
]
const MISSION_SELECT_SCIENCE_CARD_BOX := Rect2(240, 70, 160, 60)
const MISSION_SELECT_QUEST_PENALTY_BOX := Rect2(435, 70, 170, 35)
const MISSION_SELECT_QUEST_CARD_BOX := Rect2(435, 100, 170, 60)

## --- Colours taken from the mock-ups ----------------------------------------
const COLOR_BEZEL_LIGHT := Color("a49674")
const COLOR_BEZEL_DARK := Color("928667")
const COLOR_MONITOR_FRAME := Color("83817c")
const COLOR_MONITOR_BLUE := Color("4171c4")
const COLOR_MONITOR_GRID_LINE := Color("bed3fa")
const COLOR_PANEL_DARK_BLUE := Color("3e5e79")
const COLOR_LIST_GREY := Color("c2c2c2")
const COLOR_SPACE_BLACK := Color("000000")
const COLOR_EARTH_OCEAN := Color("1a11e2")
const COLOR_EARTH_LAND := Color("44902d")
const COLOR_TEXT_LIGHT := Color("ffffff")
const COLOR_WARNING_RED := Color("e23a1a")
const COLOR_ACCENT_ORANGE := Color("ff5000")


## Adds a 128 x 80 mock-up image (one of the *_BACKGROUND_PATH constants)
## stretched to SCREEN_SIZE with hard pixels, behind everything already
## added to parent; returns it. node_name names the node for tests.
static func add_mockup_background(parent: Control, image_path: String, node_name: String = "MockupBackground") -> TextureRect:
	var background := TextureRect.new()
	background.name = node_name
	background.texture = load(image_path)
	background.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	background.stretch_mode = TextureRect.STRETCH_SCALE
	background.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	background.size = SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)
	return background
