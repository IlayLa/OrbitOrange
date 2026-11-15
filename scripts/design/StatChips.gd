class_name StatChips
extends Control
## The three stat chips of the planning screens: cost against budget, total
## delta-v, and weight (total and empty). PlanningConsole places one StatChips
## on each planning screen and calls refresh when GameState.summary changes.
## The chips only show numbers from PlanSummary; they compute no mass or delta-v.

const TITLE_FONT_SIZE_PIXELS := 8
const VALUE_FONT_SIZE_PIXELS := 10
const DETAIL_FONT_SIZE_PIXELS := 8
## Tops of the three lines of a chip. Together they fit the lowest chip (38 pixels).
const TITLE_LINE_TOP_PIXELS := 0.0
const VALUE_LINE_TOP_PIXELS := 9.0
const DETAIL_LINE_TOP_PIXELS := 22.0
const TITLE_LINE_HEIGHT_PIXELS := 11.0
const VALUE_LINE_HEIGHT_PIXELS := 14.0
const COLOR_CHIP_BACKGROUND := Color("101820")
const COLOR_TITLE_TEXT := Color("bed3fa")
const EMPTY_VALUE_TEXT := "-"

## True while the cost shown is above the budget. The chip is then red.
var is_cost_over_budget: bool = false
## Points lost against spending exactly the budget. Zero when within budget.
var projected_budget_penalty_points: float = 0.0

var cost_value_label: Label
var cost_detail_label: Label
var delta_v_value_label: Label
var weight_value_label: Label
var weight_detail_label: Label


## The text lines of all chips and the size each one must have.
var _line_labels: Array[Label] = []
var _line_sizes: Array[Vector2] = []


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func _ready() -> void:
	_apply_line_sizes()


## Builds the chips. chip_rects holds the cost, delta-v and weight rectangles,
## in that order, in the coordinates of this node's parent screen. Pass
## draws_background = true where the mock-up has no chip screens of its own.
func configure(chip_rects: Array[Rect2], draws_background: bool) -> void:
	for existing_child in get_children():
		remove_child(existing_child)
		existing_child.queue_free()
	_line_labels.clear()
	_line_sizes.clear()

	var cost_labels: Array[Label] = _create_chip(chip_rects[0], "COST  M$", draws_background)
	cost_value_label = cost_labels[0]
	cost_detail_label = cost_labels[1]

	var delta_v_labels: Array[Label] = _create_chip(chip_rects[1], "DELTA-V  m/s", draws_background)
	delta_v_value_label = delta_v_labels[0]

	var weight_labels: Array[Label] = _create_chip(chip_rects[2], "WEIGHT  kg", draws_background)
	weight_value_label = weight_labels[0]
	weight_detail_label = weight_labels[1]
	_apply_line_sizes()


## Shows the numbers of the summary. A null summary (no mission yet) shows dashes.
func refresh(summary: PlanSummary, budget_million_usd: float) -> void:
	if cost_value_label == null:
		return

	if summary == null:
		is_cost_over_budget = false
		projected_budget_penalty_points = 0.0
		cost_value_label.text = EMPTY_VALUE_TEXT
		cost_detail_label.text = ""
		delta_v_value_label.text = EMPTY_VALUE_TEXT
		weight_value_label.text = EMPTY_VALUE_TEXT
		weight_detail_label.text = ""
		_set_cost_color(ScreenLayout.COLOR_TEXT_LIGHT)
		return

	var cost_million_usd: float = summary.cost_million_usd
	is_cost_over_budget = cost_million_usd > budget_million_usd
	cost_value_label.text = "%s / %s" % [
			_format_million_usd(cost_million_usd), _format_million_usd(budget_million_usd)]
	if is_cost_over_budget:
		# The penalty is measured against spending exactly the budget.
		projected_budget_penalty_points = (
				Scoring.budget_points(budget_million_usd, budget_million_usd)
				- Scoring.budget_points(cost_million_usd, budget_million_usd))
		cost_detail_label.text = "-%.1f pts" % projected_budget_penalty_points
		_set_cost_color(ScreenLayout.COLOR_WARNING_RED)
	else:
		projected_budget_penalty_points = 0.0
		cost_detail_label.text = "within budget"
		_set_cost_color(ScreenLayout.COLOR_TEXT_LIGHT)

	delta_v_value_label.text = "%.0f" % summary.total_delta_v_meters_per_second
	weight_value_label.text = "%.0f" % summary.wet_mass_kilograms
	weight_detail_label.text = "empty %.0f" % summary.dry_mass_kilograms


## Returns the value label and the detail label of the new chip.
func _create_chip(chip_rect: Rect2, title_text: String, draws_background: bool) -> Array[Label]:
	var chip := Control.new()
	chip.position = chip_rect.position
	chip.size = chip_rect.size
	chip.clip_contents = true
	chip.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(chip)

	if draws_background:
		var background := ColorRect.new()
		background.color = COLOR_CHIP_BACKGROUND
		background.size = chip_rect.size
		background.mouse_filter = Control.MOUSE_FILTER_IGNORE
		chip.add_child(background)

	var title_label: Label = _create_line(
			chip, TITLE_LINE_TOP_PIXELS, TITLE_LINE_HEIGHT_PIXELS, TITLE_FONT_SIZE_PIXELS)
	title_label.text = title_text
	title_label.add_theme_color_override("font_color", COLOR_TITLE_TEXT)

	var value_label: Label = _create_line(
			chip, VALUE_LINE_TOP_PIXELS, VALUE_LINE_HEIGHT_PIXELS, VALUE_FONT_SIZE_PIXELS)
	var detail_label: Label = _create_line(
			chip, DETAIL_LINE_TOP_PIXELS, TITLE_LINE_HEIGHT_PIXELS, DETAIL_FONT_SIZE_PIXELS)
	return [value_label, detail_label]


func _create_line(
		chip: Control,
		top_pixels: float,
		height_pixels: float,
		font_size_pixels: int) -> Label:
	var line_label := Label.new()
	line_label.position = Vector2(0, top_pixels)
	line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	line_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	line_label.clip_text = true
	line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	line_label.add_theme_font_size_override("font_size", font_size_pixels)
	line_label.add_theme_color_override("font_color", ScreenLayout.COLOR_TEXT_LIGHT)
	chip.add_child(line_label)
	_line_labels.append(line_label)
	_line_sizes.append(Vector2(chip.size.x, height_pixels))
	return line_label


## A Label cannot be lower than one line of its text, and it measures its text
## with the small font only after the theme has been applied, which Godot does
## at the end of the frame, inside the scene tree. So the sizes are set
## deferred: from _ready, and again whenever configure is called.
func _apply_line_sizes() -> void:
	if not is_inside_tree():
		return
	for line_index in _line_labels.size():
		_line_labels[line_index].set_deferred("size", _line_sizes[line_index])


func _set_cost_color(text_color: Color) -> void:
	cost_value_label.add_theme_color_override("font_color", text_color)
	cost_detail_label.add_theme_color_override("font_color", text_color)


## One decimal place, without a trailing ".0" so that whole budgets stay short.
func _format_million_usd(amount_million_usd: float) -> String:
	if is_equal_approx(amount_million_usd, roundf(amount_million_usd)):
		return "%.0f" % amount_million_usd
	return "%.1f" % amount_million_usd
