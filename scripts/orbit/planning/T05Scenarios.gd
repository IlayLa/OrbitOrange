class_name T05Scenarios
extends RefCounted
## Catalogue-only, repeatable planning fixtures shared by the demo and tests.

const CASES: Array[Dictionary] = [
	{"id": "free", "title": "Free planning", "guide": "Click a point on the closed orbit to add a pulse. Drag its base to move it and its arrow to steer or size it. Try the numeric delta-v field, Delete, and the launch-angle slider."},
	{"id": "selected", "title": "Edit a liquid pulse", "guide": "Pulse 1 is selected. Change its magnitude or drag its arrow. Inspect the old-orbit ghost, new path, stage fuel and mass readout. Add another pulse and edit the first to see the downstream prediction update."},
	{"id": "three-stage", "title": "Solid ascent + partial liquid", "guide": "Stage 1 is a large solid booster; stages 2 and 3 are liquid. In the stage list, stage 1 is spent, stage 2 has used some fuel, and stage 3 is full. Hover the ascent/path for the contributing stages. Add a pulse: stage 2 supplies it first."},
	{"id": "late-solid", "title": "Fire a solid after ascent", "guide": "Ascent leaves stage 2 partially full and stage 3's solid unlit. Pulse 1 uses exactly the liquid fuel left in stage 2. Pulse 2 then fires the whole solid in the chosen direction. Select pulse 2: its magnitude is fixed. Its retrograde kick predicts atmospheric impact; steer it to compare paths."},
	{"id": "handover", "title": "Liquid-to-solid handover", "guide": "One pulse asks for 10 m/s beyond the liquid stage's remaining capacity. It consumes stage 2, separates it, and burns the entire stage 3 solid. Delivered delta-v exceeds the request and the actual path escapes. Reduce the demand below the liquid reserve: the solid stays unlit."},
	{"id": "impact", "title": "Ascent falls short", "guide": "A single small solid motor cannot complete ascent. The predicted path ends at the atmosphere and manual pulses are unavailable. Inspect the ascent failure and fuel readouts."},
	{"id": "escape", "title": "Demand exceeds fuel", "guide": "A large prograde pulse requests more delta-v than the rocket carries. The path uses the actual delivered burn and predicts escape; the requested burn remains unaffordable. Reduce its magnitude to retain an orbit and emergency reserve."},
	{"id": "unreachable", "title": "Unreachable downstream pulse", "guide": "Pulse 1 lowers the trajectory into the atmosphere before pulse 2's chosen angle. Pulse 2 is marked unreachable and consumes no fuel. Steer or reduce pulse 1 to restore access to the later maneuver."},
	{"id": "no-liftoff", "title": "Insufficient lift-off thrust", "guide": "A cold-gas thruster with a loaded tank cannot lift the rocket. Ascent is blocked before any propellant is consumed. Compare its thrust and launch mass with the successful presets."},
]


static func create(scenario_id: String, mission: Dictionary) -> Dictionary:
	var design := RocketDesign.new()
	var plan := MissionPlan.new()
	ExampleFlight.fill_automatic_flight(design, plan)
	if scenario_id == "three-stage":
		design.stages.clear()
		design.add_stage("engine_solid_booster")
		design.add_stage("engine_liquid_hydrogen", "tank_composite_regulated")
		design.add_stage("engine_liquid_small", "tank_aluminium_blowdown")
	elif scenario_id == "late-solid" or scenario_id == "handover":
		design.stages.clear()
		design.add_stage("engine_liquid_basic", "tank_aluminium_basic")
		design.add_stage("engine_liquid_small", "tank_composite_regulated")
		design.add_stage("engine_solid_kick")
	elif scenario_id == "impact" or scenario_id == "no-liftoff":
		design.stages.clear()
		design.add_stage("engine_solid_basic" if scenario_id == "impact" else "engine_cold_gas",
				"" if scenario_id == "impact" else "tank_aluminium_blowdown")
		design.payload_part_ids.assign(["science_camera_basic"])
	var ascent := AscentPlanner.resolve(design, mission, plan.launch_angle_radians)
	var selected_id := 0
	if ascent.did_reach_initial_orbit:
		var angle: float = ascent.orbit_entry_state.polar_angle_radians() + PI / 3.0
		if scenario_id in ["selected", "escape", "unreachable"]:
			var magnitude := 100.0
			if scenario_id == "escape":
				magnitude = 100000.0
			elif scenario_id == "unreachable":
				magnitude = -500.0
			_append_pulse(plan, angle, magnitude)
			selected_id = 1
			if scenario_id == "unreachable":
				_append_pulse(plan, angle + PI, 20.0)
		elif scenario_id == "late-solid" or scenario_id == "handover":
			var current := SequentialPropulsion.current_stage(ascent.vehicle_state)
			var liquid_reserve := RocketModel.available_delta_v_meters_per_second(ascent.vehicle_state, current.stage_id)
			_append_pulse(plan, angle, liquid_reserve + (10.0 if scenario_id == "handover" else 0.0))
			selected_id = 1
			if scenario_id == "late-solid":
				_append_pulse(plan, angle + PI / 3.0, -1.0)
				selected_id = 2
	return {"design": design, "plan": plan, "selected_pulse_id": selected_id}


static func _append_pulse(plan: MissionPlan, angle_radians: float, along_meters_per_second: float) -> void:
	var pulse := Pulse.new()
	pulse.pulse_id = plan.next_free_pulse_id()
	pulse.polar_angle_radians = fposmod(angle_radians, TAU)
	pulse.delta_v_along_velocity_meters_per_second = along_meters_per_second
	plan.pulses.append(pulse)
