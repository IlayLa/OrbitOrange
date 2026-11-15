class_name PartDetailsPopup
extends Control
## The details of one part, shown while the mouse is over its card, as an
## instrument panel (design/minimize_text_walls_options.md, Option 1):
##   - the icon, the name and the cost;
##   - one chip per stat, the cost first: glyph, number and unit, never a
##     glyph alone;
##   - against the part installed in the same slot (see RocketDesign), an
##     arrow on each chip whose number differs: the arrow shows the direction
##     the number moved (up higher, down lower) and its colour the effect for
##     the player (green better, red worse). A pricier part is a red up arrow
##     on the cost; a lighter one a green down arrow on the mass;
##   - the mission-fit stars for the chosen science mission;
##   - the trade-off as a "+" line and a "-" line;
##   - a one-line source tag. The full citation is in the Data Sources codex,
##     opened by right-clicking the card (the (i) mark).
## About 130 pixels wide, nothing smaller than 8 pixels. The popup never takes
## the mouse, so it cannot make a card lose its hover.

const POPUP_WIDTH_PIXELS := 130.0
const SCREEN_MARGIN_PIXELS := 2.0
const PADDING_PIXELS := 4.0
const ICON_SIZE_PIXELS := 16.0
const TITLE_FONT_SIZE_PIXELS := 10
const BODY_FONT_SIZE_PIXELS := 8
const TITLE_LINE_HEIGHT_PIXELS := 11.0
const CHIP_ROW_HEIGHT_PIXELS := 11.0
const CHIP_GAP_PIXELS := 6.0
const TRADEOFF_MAXIMUM_LINE_COUNT := 2
const MAXIMUM_MISSION_FIT_STARS := 3
const COLOR_POPUP_BACKGROUND := Color("10182bf2")
const COLOR_POPUP_BORDER := Color("bed3fa")
const COLOR_COST_TEXT := Color("ffd27a")
const COLOR_STAR_EMPTY := Color("2a3240")

const ENGINE_TYPE_KEY := "engine_type"
const COST_KEY := "cost_million_usd"
const DRY_MASS_KEY := "dry_mass_kilograms"

## Ending of a stat key -> unit shown after the number. The first ending that
## matches wins, so longer endings come before the shorter ones they contain.
const UNIT_BY_KEY_ENDING: Array[Array] = [
	["_megabits_per_second", "Mb/s"],
	["_per_second", "per second"],
	["_kilonewtons", "kN"],
	["_kilograms", "kg"],
	["_kilometers", "km"],
	["_seconds", "s"],
	["_watts", "W"],
]
## Endings of stat keys whose value is a share of one, shown as a percentage.
const PERCENT_KEY_ENDINGS: Array[String] = ["_fraction", "_probability"]

## Stat key -> [glyph name, legend name, true when a higher value is better].
const STAT_GLYPHS := {
	"specific_impulse_seconds": ["efficiency", "efficiency (Isp)", true],
	"thrust_kilonewtons": ["thrust", "thrust", true],
	"propellant_kilograms": ["fuel", "propellant", true],
	"propellant_capacity_kilograms": ["fuel", "propellant", true],
	"pressurization": ["pressure", "pressure feed", true],
	"channel": ["channel", "what it reads", true],
	"range_kilometers": ["range", "range", true],
	"noise_fraction": ["noise", "noise", false],
	"updates_per_second": ["rate", "updates", true],
	"resolution_level": ["resolution", "detail", true],
	"dropout_probability": ["dropout", "dropout", false],
	"power_watts": ["power", "power use", false],
	"data_rate_megabits_per_second": ["data", "data rate", true],
	"science_value": ["science", "science value", true],
	DRY_MASS_KEY: ["mass", "dry mass", false],
	COST_KEY: ["money", "cost", false],
}
## The stats a category's legend explains, in the order the chips show them.
const LEGEND_KEYS_BY_CATEGORY := {
	"engine": ["specific_impulse_seconds", "thrust_kilonewtons", "propellant_kilograms", DRY_MASS_KEY],
	"tank": ["propellant_capacity_kilograms", "pressurization", DRY_MASS_KEY],
	"telemetry": ["range_kilometers", "noise_fraction", "updates_per_second", "dropout_probability"],
	"science": ["data_rate_megabits_per_second", "power_watts", "science_value", DRY_MASS_KEY],
}
## Where a trade-off sentence turns from good to bad, most telling first.
const TRADEOFF_SEPARATORS: Array[String] = [", but ", "; ", ": ", ". ", ", and the ", ", at ", ", for ", ", with ", " but "]
## Word starts that mark a drawback in a trade-off clause.
const TRADEOFF_NEGATIVE_WORDS: Array[String] = [
	"heav", "expensive", "costly", "price", "falls", "weak", "wasteful", "cannot", "only", "late",
	"noise", "slow", "glitch", "no use", "hungr", "more mass", "modest", "fires once", "burns everything",
	"needs", "without", "wants", "fixed", "roughly",
]
## Phrases removed before the check because a negative word in them is praise.
const TRADEOFF_POSITIVE_PHRASES: Array[String] = ["lift a heavy rocket"]
const RESOLUTION_LEVEL_NAMES: Array[String] = ["blip", "bearing", "shape"]
## Names searched in a source, most specific first, for the one-line tag.
const SOURCE_ORGANIZATIONS: Array[String] = [
	"Northrop Grumman", "Aerojet Rocketdyne", "Rocket Lab", "SpaceX", "NASA", "Wikipedia",
]

## Where the popup would like its top-left corner, before it is kept on screen.
var _wanted_position: Vector2 = Vector2.ZERO
var _part: Dictionary = {}
var _icon: Texture2D
var _name_lines: Array[String] = []
## One Dictionary per stat chip: "glyph", "text", "direction" and "effect"
## (see stat_chips), "position" (Vector2, set by _layout).
var _chips: Array[Dictionary] = []
var _fit_star_count: int = -1
var _plus_lines: Array[String] = []
var _minus_lines: Array[String] = []
## A trade-off that names no drawback, shown without a sign.
var _neutral_lines: Array[String] = []
var _source_tag: String = ""
var _section_tops: Dictionary = {}


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	hide()


## Fills the popup for one entry of data/parts.json and shows it with its
## top-left corner at wanted_position, moved as needed to stay on the screen.
## science_mission_id chooses which mission-fit rating the stars show.
## compared_part is the part installed in the same slot (an empty Dictionary
## for an empty slot); each stat chip then carries a better or worse arrow.
func show_part(part: Dictionary, science_mission_id: String, wanted_position: Vector2,
		compared_part: Dictionary = {}) -> void:
	_part = part
	_icon = null
	var icon_path: String = part.get("icon_path", "")
	if not icon_path.is_empty() and ResourceLoader.exists(icon_path):
		_icon = load(icon_path)
	var compared: Dictionary = {} if compared_part.get("id", "") == part.get("id", "") else compared_part

	_chips = stat_chips(part, compared)
	_fit_star_count = mission_fit_stars(part, science_mission_id) if part.get("category", "") == GameData.CATEGORY_SCIENCE and not science_mission_id.is_empty() else -1
	var tradeoff_halves: Array[String] = tradeoff_parts(part.get("tradeoff", ""))
	var tradeoff_width: float = POPUP_WIDTH_PIXELS - 2.0 * PADDING_PIXELS - PixelGlyphs.GLYPH_ADVANCE_PIXELS
	_plus_lines = PixelGlyphs.wrap_lines(tradeoff_halves[0], tradeoff_width, TRADEOFF_MAXIMUM_LINE_COUNT)
	_minus_lines = PixelGlyphs.wrap_lines(tradeoff_halves[1], tradeoff_width, TRADEOFF_MAXIMUM_LINE_COUNT)
	_neutral_lines = PixelGlyphs.wrap_lines(tradeoff_halves[2], tradeoff_width, TRADEOFF_MAXIMUM_LINE_COUNT)
	_source_tag = short_source_tag(part)
	_layout()

	_wanted_position = wanted_position
	show()
	_keep_on_screen()
	queue_redraw()


## The stat chips of a part, the cost first and the dry mass last. Each has
## "glyph", "text", and against compared_part:
##   "direction"  1 when the number is higher, -1 when lower, 0 when equal
##                or there is nothing to compare: the arrow's shape
##   "effect"     1 when that is better for the player, -1 when worse, 0
##                with no arrow: the arrow's colour
static func stat_chips(part: Dictionary, compared_part: Dictionary = {}) -> Array[Dictionary]:
	var chips: Array[Dictionary] = []
	var stats: Dictionary = part.get("stats", {})
	var compared_stats: Dictionary = compared_part.get("stats", {})
	var cost_million_usd: float = part.get(COST_KEY, 0.0)
	chips.append(_chip(COST_KEY, NumberFormat.money(cost_million_usd), cost_million_usd, compared_part.get(COST_KEY, null), compared_part.is_empty()))
	if stats.has(ENGINE_TYPE_KEY):
		chips.append({"glyph": "", "text": str(stats[ENGINE_TYPE_KEY]).to_upper(), "direction": 0, "effect": 0})
	for stat_key: String in stats:
		if stat_key == ENGINE_TYPE_KEY:
			continue
		var stat_value: Variant = stats[stat_key]
		if stat_key == "range_kilometers" and float(stat_value) <= 0.0:
			continue
		chips.append(_chip(stat_key, stat_chip_text(stat_key, stat_value), stat_value, compared_stats.get(stat_key, null), compared_part.is_empty()))
	var dry_mass_kilograms: float = part.get(DRY_MASS_KEY, 0.0)
	chips.append(_chip(DRY_MASS_KEY, stat_chip_text(DRY_MASS_KEY, dry_mass_kilograms), dry_mass_kilograms,
			compared_part.get(DRY_MASS_KEY, null), compared_part.is_empty()))
	return chips


static func _chip(stat_key: String, text: String, value: Variant, compared_value: Variant, has_no_comparison: bool) -> Dictionary:
	var direction := 0
	if not has_no_comparison:
		direction = _direction(value, compared_value)
	var is_higher_better: bool = STAT_GLYPHS.get(stat_key, ["", "", true])[2]
	var effect := 0
	if direction != 0:
		effect = 1 if (direction > 0) == is_higher_better else -1
	return {"glyph": glyph_for_stat(stat_key), "text": text, "direction": direction, "effect": effect}


## The glyph of a stat key, or "" when it has none.
static func glyph_for_stat(stat_key: String) -> String:
	if STAT_GLYPHS.has(stat_key):
		return STAT_GLYPHS[stat_key][0]
	return ""


## The legend of a category: [glyph name, name] per stat, then cost.
static func legend_entries(category: String) -> Array[Array]:
	var entries: Array[Array] = []
	for stat_key: String in LEGEND_KEYS_BY_CATEGORY.get(category, []):
		entries.append([STAT_GLYPHS[stat_key][0], STAT_GLYPHS[stat_key][1]])
	return entries


## A stat value as a short number with its unit and no space: "290s",
## "47kN", "16.2t", "5%", "0.5/s", "bearing".
static func stat_chip_text(stat_key: String, stat_value: Variant) -> String:
	if stat_key == "resolution_level":
		return RESOLUTION_LEVEL_NAMES[clampi(int(stat_value), 0, RESOLUTION_LEVEL_NAMES.size() - 1)]
	if not (stat_value is float or stat_value is int):
		var text_value: String = str(stat_value)
		if stat_key == "channel":
			return text_value.get_slice("_", 0)
		return text_value.replace("_", " ")
	var number_value: float = stat_value
	for percent_key_ending in PERCENT_KEY_ENDINGS:
		if stat_key.ends_with(percent_key_ending):
			return _short_number(100.0 * number_value) + "%"
	if stat_key.ends_with("_kilograms") and number_value >= 10000.0:
		return _short_number(number_value / 1000.0) + "t"
	if stat_key == "updates_per_second":
		return _short_number(number_value) + "/s"
	if stat_key == "science_value":
		return "%s/3" % _short_number(number_value)
	for ending_and_unit in UNIT_BY_KEY_ENDING:
		var key_ending: String = ending_and_unit[0]
		if stat_key.ends_with(key_ending):
			return _short_number(number_value) + ending_and_unit[1]
	return _short_number(number_value)


## The trade-off sentence as [good part, bad part, neutral text]. The
## sentence is cut into clauses at every separator of TRADEOFF_SEPARATORS;
## a clause with a word of TRADEOFF_NEGATIVE_WORDS is bad, the others good.
## A sentence with no bad clause names no drawback: it is returned whole as
## the neutral text and shown without a + or -, never as a benefit.
static func tradeoff_parts(tradeoff: String) -> Array[String]:
	var text := tradeoff.strip_edges().trim_suffix(".")
	if text.is_empty():
		return ["", "", ""]
	var clauses: Array[String] = [text]
	for separator in TRADEOFF_SEPARATORS:
		var split_clauses: Array[String] = []
		for clause in clauses:
			for piece in clause.split(separator, false):
				if not piece.strip_edges().is_empty():
					split_clauses.append(piece.strip_edges())
		clauses = split_clauses
	var good_clauses: PackedStringArray = []
	var bad_clauses: PackedStringArray = []
	for clause in clauses:
		if is_negative_clause(clause):
			bad_clauses.append(clause)
		else:
			good_clauses.append(clause)
	if bad_clauses.is_empty():
		return ["", "", text]
	return [", ".join(good_clauses), ", ".join(bad_clauses), ""]


## True when a clause names a drawback: a word of TRADEOFF_NEGATIVE_WORDS
## starts a word in it ("glitch" matches "glitches"). Phrases of
## TRADEOFF_POSITIVE_PHRASES are removed first ("lift a heavy rocket").
static func is_negative_clause(clause: String) -> bool:
	var lower_clause := " " + clause.to_lower()
	for positive_phrase in TRADEOFF_POSITIVE_PHRASES:
		lower_clause = lower_clause.replace(positive_phrase, "")
	for negative_word in TRADEOFF_NEGATIVE_WORDS:
		var word_position := lower_clause.find(negative_word)
		while word_position >= 0:
			var previous_character := lower_clause[word_position - 1] if word_position > 0 else " "
			if not (previous_character >= "a" and previous_character <= "z"):
				return true
			word_position = lower_clause.find(negative_word, word_position + 1)
	return false


## A one-line source tag, for example "src: Northrop Grumman" or
## "src: estimate (NASA) ≈". The full citation is in the Data Sources codex.
static func short_source_tag(part: Dictionary) -> String:
	var source: String = part.get("source", "")
	if source.is_empty():
		return ""
	var tag := ""
	if source.begins_with("Estimate"):
		tag = "estimate"
		if source.contains("NASA"):
			tag += " (NASA class)"
	else:
		for organization in SOURCE_ORGANIZATIONS:
			if source.contains(organization):
				tag = organization
				break
		if tag.is_empty():
			tag = source.get_slice(":", 0).get_slice(".", 0).get_slice(";", 0)
	var is_approximate: bool = part.get("is_approximate", false)
	return "src: " + tag + (" ≈" if is_approximate else "")


## The name, the category, the cost, the dry mass and one line per stat, as
## sentences. Kept for the Data Sources codex and for tests.
static func detail_lines(part: Dictionary) -> Array[String]:
	var lines: Array[String] = []
	var part_id: String = part.get("id", "")
	lines.append(part.get("name", part_id))

	var stats: Dictionary = part.get("stats", {})
	var category: String = part.get("category", "")
	if stats.has(ENGINE_TYPE_KEY):
		lines.append("Engine type: %s" % stats[ENGINE_TYPE_KEY])
	else:
		lines.append("Category: %s" % category)

	var cost_million_usd: float = part.get(COST_KEY, 0.0)
	lines.append("Cost: %s million USD" % PartCard.format_number(cost_million_usd))
	var dry_mass_kilograms: float = part.get(DRY_MASS_KEY, 0.0)
	lines.append("Dry mass: %s kg" % PartCard.format_number(dry_mass_kilograms))

	for stat_key: String in stats:
		if stat_key == ENGINE_TYPE_KEY:
			continue
		lines.append(stat_line(stat_key, stats[stat_key]))
	return lines


## One stat as "Readable name: value unit". The unit comes from the ending of
## the key, for example "thrust_kilonewtons" -> "Thrust: 47 kN".
static func stat_line(stat_key: String, stat_value: Variant) -> String:
	if not (stat_value is float or stat_value is int):
		var text_value: String = str(stat_value).replace("_", " ")
		return "%s: %s" % [_readable_name(stat_key), text_value]

	var number_value: float = stat_value
	for percent_key_ending in PERCENT_KEY_ENDINGS:
		if stat_key.ends_with(percent_key_ending):
			return "%s: %s %%" % [
					_readable_name(stat_key.trim_suffix(percent_key_ending)),
					PartCard.format_number(100.0 * number_value)]

	for ending_and_unit in UNIT_BY_KEY_ENDING:
		var key_ending: String = ending_and_unit[0]
		var unit: String = ending_and_unit[1]
		if stat_key.ends_with(key_ending):
			return "%s: %s %s" % [
					_readable_name(stat_key.trim_suffix(key_ending)),
					PartCard.format_number(number_value),
					unit]

	return "%s: %s" % [_readable_name(stat_key), PartCard.format_number(number_value)]


## The mission-fit rating of the part for one science mission, from 0 to 3.
static func mission_fit_stars(part: Dictionary, science_mission_id: String) -> int:
	var mission_fit: Dictionary = part.get("mission_fit", {})
	var rating: float = mission_fit.get(science_mission_id, 0)
	return clampi(roundi(rating), 0, MAXIMUM_MISSION_FIT_STARS)


## The full citation, for the Data Sources codex.
static func source_line(part: Dictionary) -> String:
	var source: String = part.get("source", "")
	if source.is_empty():
		return ""
	var is_approximate: bool = part.get("is_approximate", false)
	if is_approximate:
		return "Source (approximate): " + source
	return "Source: " + source


## Draws "fit" and three stars, filled for the rating and dark for the rest,
## then "2/3": the count is written too, so colour is not the only signal.
## Returns the width taken.
static func draw_fit_stars(canvas: CanvasItem, top_left: Vector2, star_count: int, label_text: String = "fit") -> float:
	var next_left: float = top_left.x
	if not label_text.is_empty():
		next_left += PixelGlyphs.draw_text(canvas, top_left, label_text, PixelGlyphs.COLOR_MUTED_TEXT) + 3.0
	for star_index in MAXIMUM_MISSION_FIT_STARS:
		var star_color: Color = ScreenLayout.COLOR_ACCENT_ORANGE if star_index < star_count else COLOR_STAR_EMPTY
		PixelGlyphs.draw_glyph(canvas, "star", Vector2(next_left + 1.0, top_left.y + 1.0), star_color)
		next_left += 9.0
	next_left += 2.0
	next_left += PixelGlyphs.draw_text(canvas, Vector2(next_left, top_left.y), "%d/3" % star_count, ScreenLayout.COLOR_TEXT_LIGHT)
	return next_left - top_left.x


static func _readable_name(key_text: String) -> String:
	return key_text.replace("_", " ").capitalize()


static func _short_number(value: float) -> String:
	if value != 0.0 and absf(value) < 0.1:
		return ("%.2f" % value).rstrip("0").rstrip(".")
	return NumberFormat.compact(value)


## 1 when value is higher than compared_value, -1 when lower, 0 when equal
## or not comparable (a text, or nothing installed).
static func _direction(value: Variant, compared_value: Variant) -> int:
	if not (value is float or value is int) or not (compared_value is float or compared_value is int):
		return 0
	if is_equal_approx(float(value), float(compared_value)):
		return 0
	return 1 if float(value) > float(compared_value) else -1


func _layout() -> void:
	var inner_width: float = POPUP_WIDTH_PIXELS - 2.0 * PADDING_PIXELS
	var name_left: float = ICON_SIZE_PIXELS + 4.0
	# The whole width beside the icon, so that names break between words.
	_name_lines = PixelGlyphs.wrap_lines(_part.get("name", _part.get("id", "")),
			inner_width - name_left, 2, TITLE_FONT_SIZE_PIXELS)
	var next_top: float = PADDING_PIXELS + maxf(ICON_SIZE_PIXELS, _name_lines.size() * TITLE_LINE_HEIGHT_PIXELS) + 3.0

	var row_left: float = PADDING_PIXELS
	for chip in _chips:
		var chip_width: float = _chip_width(chip)
		if row_left > PADDING_PIXELS and row_left + chip_width > PADDING_PIXELS + inner_width:
			row_left = PADDING_PIXELS
			next_top += CHIP_ROW_HEIGHT_PIXELS
		chip["position"] = Vector2(row_left, next_top)
		row_left += chip_width + CHIP_GAP_PIXELS
	next_top += CHIP_ROW_HEIGHT_PIXELS + 2.0

	_section_tops.clear()
	if _fit_star_count >= 0:
		_section_tops["fit"] = next_top
		next_top += CHIP_ROW_HEIGHT_PIXELS
	if not _plus_lines.is_empty() and not _plus_lines[0].is_empty():
		_section_tops["plus"] = next_top
		next_top += _plus_lines.size() * PixelGlyphs.LINE_HEIGHT_PIXELS + 1.0
	if not _minus_lines.is_empty() and not _minus_lines[0].is_empty():
		_section_tops["minus"] = next_top
		next_top += _minus_lines.size() * PixelGlyphs.LINE_HEIGHT_PIXELS + 1.0
	if not _neutral_lines.is_empty() and not _neutral_lines[0].is_empty():
		_section_tops["neutral"] = next_top
		next_top += _neutral_lines.size() * PixelGlyphs.LINE_HEIGHT_PIXELS + 1.0
	if not _source_tag.is_empty():
		next_top += 2.0
		_section_tops["source"] = next_top
		next_top += CHIP_ROW_HEIGHT_PIXELS
	size = Vector2(POPUP_WIDTH_PIXELS, ceilf(next_top + PADDING_PIXELS - 2.0))


func _chip_width(chip: Dictionary) -> float:
	var width: float = PixelGlyphs.chip_width(chip["glyph"], chip["text"])
	if chip["direction"] != 0:
		width += PixelGlyphs.GLYPH_ADVANCE_PIXELS - 1.0
	return width


func _draw() -> void:
	if _part.is_empty():
		return
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_POPUP_BACKGROUND)
	draw_rect(Rect2(Vector2.ZERO, size), COLOR_POPUP_BORDER, false, 1.0)
	var inner_width: float = POPUP_WIDTH_PIXELS - 2.0 * PADDING_PIXELS

	if _icon != null:
		draw_texture_rect(_icon, Rect2(Vector2(PADDING_PIXELS, PADDING_PIXELS), Vector2(ICON_SIZE_PIXELS, ICON_SIZE_PIXELS)), false)
	for line_index in _name_lines.size():
		PixelGlyphs.draw_text(self, Vector2(PADDING_PIXELS + ICON_SIZE_PIXELS + 4.0, PADDING_PIXELS - 1.0 + line_index * TITLE_LINE_HEIGHT_PIXELS),
				_name_lines[line_index], ScreenLayout.COLOR_TEXT_LIGHT, TITLE_FONT_SIZE_PIXELS)
	for chip in _chips:
		_draw_chip(chip, chip["position"], COLOR_COST_TEXT if chip["glyph"] == "money" else ScreenLayout.COLOR_TEXT_LIGHT)

	if _section_tops.has("fit"):
		draw_fit_stars(self, Vector2(PADDING_PIXELS, _section_tops["fit"]), _fit_star_count)
	if _section_tops.has("plus"):
		_draw_tradeoff("plus", _plus_lines, PixelGlyphs.COLOR_GOOD_GREEN)
	if _section_tops.has("minus"):
		_draw_tradeoff("minus", _minus_lines, ScreenLayout.COLOR_WARNING_RED)
	if _section_tops.has("neutral"):
		# No glyph: "neutral" is not a glyph name, so only the text is drawn.
		_draw_tradeoff("neutral", _neutral_lines, ScreenLayout.COLOR_TEXT_LIGHT)
	if _section_tops.has("source"):
		var source_top: float = _section_tops["source"]
		draw_line(Vector2(PADDING_PIXELS, source_top - 2.0), Vector2(PADDING_PIXELS + inner_width, source_top - 2.0),
				Color(COLOR_POPUP_BORDER, 0.3), 1.0)
		PixelGlyphs.draw_text(self, Vector2(PADDING_PIXELS, source_top), _source_tag, PixelGlyphs.COLOR_MUTED_TEXT,
				BODY_FONT_SIZE_PIXELS, inner_width - PixelGlyphs.GLYPH_ADVANCE_PIXELS - 2.0)
		PixelGlyphs.draw_glyph(self, "info", Vector2(PADDING_PIXELS + inner_width - 7.0, source_top + 1.0), COLOR_POPUP_BORDER)


func _draw_chip(chip: Dictionary, top_left: Vector2, text_color: Color) -> void:
	var glyph_color: Color = COLOR_POPUP_BORDER
	var width: float = PixelGlyphs.draw_chip(self, top_left, chip["glyph"], chip["text"], glyph_color, text_color)
	var direction: int = chip["direction"]
	if direction == 0:
		return
	PixelGlyphs.draw_glyph(self, delta_arrow_glyph(direction), top_left + Vector2(width + 2.0, 1.0), delta_arrow_color(chip["effect"]))


## The arrow's shape: the direction the number moved.
static func delta_arrow_glyph(direction: int) -> String:
	return "arrow_up" if direction > 0 else "arrow_down"


## The arrow's colour: the effect for the player.
static func delta_arrow_color(effect: int) -> Color:
	return PixelGlyphs.COLOR_GOOD_GREEN if effect > 0 else ScreenLayout.COLOR_WARNING_RED


func _draw_tradeoff(section_name: String, lines: Array[String], sign_color: Color) -> void:
	var section_top: float = _section_tops[section_name]
	PixelGlyphs.draw_glyph(self, section_name, Vector2(PADDING_PIXELS + 1.0, section_top + 1.0), sign_color)
	for line_index in lines.size():
		PixelGlyphs.draw_text(self, Vector2(PADDING_PIXELS + PixelGlyphs.GLYPH_ADVANCE_PIXELS, section_top + line_index * PixelGlyphs.LINE_HEIGHT_PIXELS),
				lines[line_index], ScreenLayout.COLOR_TEXT_LIGHT)


func _keep_on_screen() -> void:
	var highest_left_pixels: float = ScreenLayout.SCREEN_SIZE.x - size.x - SCREEN_MARGIN_PIXELS
	var highest_top_pixels: float = ScreenLayout.SCREEN_SIZE.y - size.y - SCREEN_MARGIN_PIXELS
	position = Vector2(
			clampf(_wanted_position.x, SCREEN_MARGIN_PIXELS, maxf(SCREEN_MARGIN_PIXELS, highest_left_pixels)),
			clampf(_wanted_position.y, SCREEN_MARGIN_PIXELS, maxf(SCREEN_MARGIN_PIXELS, highest_top_pixels))).round()
