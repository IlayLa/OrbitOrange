extends RefCounted
## Computes the independent event rate for one altitude and simulation time.


## Returns the effective event rate in events per simulated hour.
static func effective_rate_events_per_hour(
		event_type: Dictionary, mission: Dictionary, accepted_side_quests: Array[Dictionary],
		altitude_kilometers: float, time_seconds: float) -> float:
	if time_seconds < float(event_type.get("earliest_time_seconds", 0.0)):
		return 0.0
	var event_type_id: String = event_type["id"]
	var hazard_rates: Dictionary = mission.get("hazard_rates", {})
	var events_per_hour := 0.0
	for band: Dictionary in hazard_rates.get(event_type_id, []):
		if _contains_altitude(band, altitude_kilometers):
			events_per_hour = float(band["events_per_hour"])
			break
	if events_per_hour <= 0.0:
		return 0.0
	for zone: Dictionary in mission.get("hazard_zones", []):
		if event_type_id in zone.get("event_type_ids", []) and _contains_altitude(zone, altitude_kilometers):
			events_per_hour *= float(event_type.get("inside_zone_multiplier", 1.0))
			break
	for quest in accepted_side_quests:
		if event_type_id in quest.get("related_event_type_ids", []):
			events_per_hour *= float(quest.get("related_multiplier", 1.0))
		else:
			events_per_hour *= 1.0 + float(quest.get("unrelated_bonus", 0.0))
	return maxf(0.0, events_per_hour)


static func _contains_altitude(band: Dictionary, altitude_kilometers: float) -> bool:
	return (altitude_kilometers >= float(band["inner_altitude_kilometers"])
			and altitude_kilometers < float(band["outer_altitude_kilometers"]))
