extends Node
## Reads the JSON files in res://data once at start-up and hands out their
## entries by id. Every module reads the catalogue through this node, so no
## other script opens a data file. The schemas are described in tasks/CONTRACTS.md.
## Owned by the integrator.

const PARTS_FILE_PATH := "res://data/parts.json"
const MISSIONS_FILE_PATH := "res://data/missions.json"
const BODIES_FILE_PATH := "res://data/bodies.json"
const EVENT_TYPES_FILE_PATH := "res://data/event_types.json"

const CATEGORY_ENGINE := "engine"
const CATEGORY_TANK := "tank"
const CATEGORY_TELEMETRY := "telemetry"
const CATEGORY_SCIENCE := "science"

var parts_by_id: Dictionary = {}
var missions_by_id: Dictionary = {}
var bodies_by_id: Dictionary = {}
var event_types_by_id: Dictionary = {}


func _ready() -> void:
	reload_all()


func reload_all() -> void:
	parts_by_id = load_entries_by_id(PARTS_FILE_PATH)
	missions_by_id = load_entries_by_id(MISSIONS_FILE_PATH)
	bodies_by_id = load_entries_by_id(BODIES_FILE_PATH)
	event_types_by_id = load_entries_by_id(EVENT_TYPES_FILE_PATH)


## Reads a JSON file that holds a list of entries, each with an "id" key.
## Returns id -> entry. Reports an error and returns what it could read when
## the file is missing or malformed.
func load_entries_by_id(file_path: String) -> Dictionary:
	var entries_by_id := {}
	if not FileAccess.file_exists(file_path):
		push_error("GameData: file not found: " + file_path)
		return entries_by_id

	var file_text := FileAccess.get_file_as_string(file_path)
	var parsed_content: Variant = JSON.parse_string(file_text)
	if not parsed_content is Array:
		push_error("GameData: expected a JSON list at the top of " + file_path)
		return entries_by_id

	for entry: Variant in parsed_content:
		if entry is Dictionary and entry.has("id"):
			entries_by_id[entry["id"]] = entry
		else:
			push_error("GameData: an entry without an \"id\" in " + file_path)
	return entries_by_id


## Returns an empty Dictionary when the id is unknown.
func part(part_id: String) -> Dictionary:
	return parts_by_id.get(part_id, {})


## All parts of one category ("engine", "tank", "telemetry" or "science"),
## ordered by tier and then by cost.
func parts_in_category(category: String) -> Array[Dictionary]:
	var matching_parts: Array[Dictionary] = []
	for part_id: String in parts_by_id:
		var candidate_part: Dictionary = parts_by_id[part_id]
		if candidate_part.get("category", "") == category:
			matching_parts.append(candidate_part)
	matching_parts.sort_custom(_is_part_listed_before)
	return matching_parts


func all_missions() -> Array[Dictionary]:
	var missions: Array[Dictionary] = []
	for mission_id: String in missions_by_id:
		missions.append(missions_by_id[mission_id])
	return missions


func mission(mission_id: String) -> Dictionary:
	return missions_by_id.get(mission_id, {})


func body(body_id: String) -> Dictionary:
	return bodies_by_id.get(body_id, {})


func all_event_types() -> Array[Dictionary]:
	var event_types: Array[Dictionary] = []
	for event_type_id: String in event_types_by_id:
		event_types.append(event_types_by_id[event_type_id])
	return event_types


func event_type(event_type_id: String) -> Dictionary:
	return event_types_by_id.get(event_type_id, {})


## For tests: adds or replaces one part without touching the JSON file.
func register_part(new_part: Dictionary) -> void:
	parts_by_id[new_part["id"]] = new_part


func _is_part_listed_before(first_part: Dictionary, second_part: Dictionary) -> bool:
	var first_tier: float = first_part.get("tier", 0)
	var second_tier: float = second_part.get("tier", 0)
	if first_tier != second_tier:
		return first_tier < second_tier
	var first_cost: float = first_part.get("cost_million_usd", 0.0)
	var second_cost: float = second_part.get("cost_million_usd", 0.0)
	return first_cost < second_cost
