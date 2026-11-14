class_name ScoreLine
extends RefCounted
## One row of the final score table.

## "Mission", "Budget", "Science" or "Side quests".
var part_name: String = ""
## For example "Altitude accuracy".
var line_name: String = ""
var points: float = 0.0
var maximum_points: float = 0.0
## One sentence telling the player why they got these points.
var explanation: String = ""


static func create(
		new_part_name: String,
		new_line_name: String,
		new_points: float,
		new_maximum_points: float,
		new_explanation: String) -> ScoreLine:
	var line := ScoreLine.new()
	line.part_name = new_part_name
	line.line_name = new_line_name
	line.points = new_points
	line.maximum_points = new_maximum_points
	line.explanation = new_explanation
	return line
