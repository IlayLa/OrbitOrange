class_name Stage
extends RefCounted
## One rocket stage: an engine and, for liquid engines, the tank that feeds it.

## Unique within one RocketDesign. Stays the same when other stages are added or removed.
var stage_id: int = 0
## Id of a part in data/parts.json with category "engine".
var engine_part_id: String = ""
## Id of a part with category "tank". Empty for a solid motor, which carries its own propellant.
var tank_part_id: String = ""
