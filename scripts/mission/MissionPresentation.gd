class_name MissionPresentation
extends RefCounted
## Shared presentation helpers used only by mission screens and their demo.

## Returns a theme with pixel-sized controls and the shared screen colours.
## Buttons take their skin from the project theme (assets/ui/ui_theme.tres).
static func create_theme() -> Theme:
	var result := Theme.new()
	result.default_font_size = 14
	result.set_color("font_color", "Label", ScreenLayout.COLOR_TEXT_LIGHT)
	return result

## Creates a non-interactive background filling the 640 by 400 pixel canvas.
static func add_background(parent: Control) -> void:
	var background := ColorRect.new()
	background.color = ScreenLayout.COLOR_BEZEL_DARK
	background.size = ScreenLayout.SCREEN_SIZE
	background.mouse_filter = Control.MOUSE_FILTER_IGNORE
	parent.add_child(background)

## Returns a wrapping label and adds it to the supplied container.
static func add_label(parent: Node, text: String, font_size: int = 14) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("font_size", font_size)
	parent.add_child(label)
	return label

## Returns the vertical contents of a scrollable monitor at the pixel rectangle.
static func add_monitor(parent: Control, rectangle: Rect2) -> VBoxContainer:
	var panel := PanelContainer.new()
	panel.position = rectangle.position
	panel.size = rectangle.size
	var style := StyleBoxFlat.new()
	style.bg_color = ScreenLayout.COLOR_SPACE_BLACK
	style.border_color = ScreenLayout.COLOR_MONITOR_FRAME
	style.set_border_width_all(3)
	style.set_content_margin_all(9)
	panel.add_theme_stylebox_override("panel", style)
	parent.add_child(panel)
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	panel.add_child(scroll)
	var contents := VBoxContainer.new()
	contents.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	contents.add_theme_constant_override("separation", 9)
	scroll.add_child(contents)
	return contents

## Removes a container's children immediately from layout, freeing them later.
static func clear_contents(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()

## Returns an altitude-band description in kilometres.
static func zone_text(zone: Dictionary) -> String:
	return "%.0f-%.0f km altitude" % [float(zone.get("inner_altitude_kilometers", 0.0)), float(zone.get("outer_altitude_kilometers", 0.0))]


## Display names of the score groups, in the order the final screen shows them.
const SCORE_GROUPS: Array[Array] = [
	["Mission", "MISSION"],
	["Budget", "BUDGET"],
	["Science", "SCIENCE"],
	["Side quests", "QUESTS"],
]
## Two or three words naming why a score line lost points.
const LOSS_TAGS := {
	"Orbit achieved": "no orbit",
	"Altitude accuracy": "alt. off",
	"Orbit shape": "ecc. off",
	"Vehicle health": "parts down",
	"Within budget": "over budget",
	"Margin": "thin margin",
	"Instrument fit": "weak fit",
	"Coverage": "low coverage",
	"Data returned": "data short",
	"Failure penalty": "penalty",
}
## Failed quests lose points (and, separately, their grant).
const QUEST_LOSS_TAG := "quest failed"


## The score grouped for the final screen's bars. One Dictionary per group
## in SCORE_GROUPS order: "part_name", "title", "earned_points" (sum of the
## positive points), "maximum_points", "penalty_points" (sum of the negative
## points, zero or below), "tag" (2-3 words and the loss, for example
## "ecc. off −2"; "full marks" without a loss; "none taken" for no lines),
## "has_loss" and "lines" (the ScoreLines, whose explanations stay available).
static func score_groups(score: ScoreReport) -> Array[Dictionary]:
	var groups: Array[Dictionary] = []
	for group_names in SCORE_GROUPS:
		var group_lines: Array[ScoreLine] = []
		if score != null:
			for line in score.lines:
				if line.part_name == group_names[0]:
					group_lines.append(line)
		var earned_points := 0.0
		var maximum_points := 0.0
		var penalty_points := 0.0
		var largest_loss_points := 0.0
		var largest_loss_tag := ""
		for line in group_lines:
			maximum_points += line.maximum_points
			if line.points < 0.0:
				penalty_points += line.points
			else:
				earned_points += line.points
			var loss_points: float = line.maximum_points - line.points
			if loss_points > largest_loss_points + 0.05:
				largest_loss_points = loss_points
				largest_loss_tag = LOSS_TAGS.get(line.line_name, QUEST_LOSS_TAG if group_names[0] == "Side quests" else line.line_name.to_lower())
		var tag := "full marks"
		if group_lines.is_empty():
			tag = "none taken"
		elif not largest_loss_tag.is_empty():
			tag = "%s %s" % [largest_loss_tag, NumberFormat.points_row(-largest_loss_points)]
		groups.append({
			"part_name": group_names[0],
			"title": group_names[1],
			"earned_points": earned_points,
			"maximum_points": maximum_points,
			"penalty_points": penalty_points,
			"tag": tag,
			"has_loss": not largest_loss_tag.is_empty(),
			"lines": group_lines,
		})
	return groups


## Every line of a group as "Name 12.5/15: explanation", for the detail box.
static func group_explanation(group: Dictionary) -> String:
	var sentences: PackedStringArray = []
	for line: ScoreLine in group["lines"]:
		sentences.append("%s %s/%s: %s" % [line.line_name, NumberFormat.points_row(line.points),
				NumberFormat.points_row(line.maximum_points), line.explanation])
	if sentences.is_empty():
		return "No side quests were taken."
	return "\n".join(sentences)


## Severity of the outcomes EventDirector and EventFaults (T07) write in the
## event log. The log has no structured severity field (FlightResult.gd), so
## known outcomes are looked up here first.
const EVENT_OUTCOME_SEVERITIES := {
	"collision": WarningLamps.Severity.BLOCKING,
	"damage": WarningLamps.Severity.BLOCKING,
	"sensor failed": WarningLamps.Severity.BLOCKING,
	"engine failed": WarningLamps.Severity.BLOCKING,
	"engine weakened": WarningLamps.Severity.BLOCKING,
	"leak started": WarningLamps.Severity.BLOCKING,
	"interference": WarningLamps.Severity.WARNING,
	"pending": WarningLamps.Severity.WARNING,
	"threat avoided": WarningLamps.Severity.OK,
	"skipped": WarningLamps.Severity.OK,
}
## Whole words that mark damage in an outcome not listed above.
const EVENT_DAMAGE_WORDS: Array[String] = ["collision", "collided", "destroyed", "hit", "lost", "failed", "failure", "damage", "damaged", "leak"]
## Whole words that mark a harmless outcome, or cancel a damage word
## ("Collision avoided", "No damage").
const EVENT_SAFE_WORDS: Array[String] = ["avoided", "prevented", "no", "without", "safe", "safely", "clear", "skipped", "none"]


## The lamp severity of a flight event, for its timeline pip: BLOCKING (✖)
## for damage, OK (●) for a harmless outcome or one the player reacted to,
## WARNING (▲) for an event that was only watched. Known T07 outcomes come
## from EVENT_OUTCOME_SEVERITIES; other text is read word by word, and a
## safe word such as "avoided" or "no" outweighs a damage word.
static func event_severity(event: Dictionary) -> int:
	var outcome: String = str(event.get("outcome", "")).strip_edges().to_lower()
	if EVENT_OUTCOME_SEVERITIES.has(outcome):
		return EVENT_OUTCOME_SEVERITIES[outcome]
	var words: PackedStringArray = []
	for word in outcome.replace("-", " ").replace(",", " ").replace(".", " ").split(" ", false):
		words.append(word)
	var has_safe_word := false
	for safe_word in EVENT_SAFE_WORDS:
		has_safe_word = has_safe_word or words.has(safe_word)
	if has_safe_word:
		return WarningLamps.Severity.OK
	for damage_word in EVENT_DAMAGE_WORDS:
		if words.has(damage_word):
			return WarningLamps.Severity.BLOCKING
	if event.get("did_player_react", false):
		return WarningLamps.Severity.OK
	return WarningLamps.Severity.WARNING
