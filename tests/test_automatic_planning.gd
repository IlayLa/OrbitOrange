extends RefCounted
## Physical regression checks for automatic ascent and sequential staging.

const Flight = preload("res://autoload/FlightSimulation.gd")
const LIQUID_ID := "t05_test_liquid"
const TANK_ID := "t05_test_tank"
const SOLID_ID := "t05_test_solid"
const BOOSTER_ID := "t05_test_booster"
const SMALL_TANK_ID := "t05_test_small_tank"


func run_tests(report: TestReport) -> void:
	_register_parts()
	_check_handover(report)
	_check_ascent(report)
	_check_three_stage_ascent(report)
	_check_reassignment_and_reachability(report)
	_check_flight_agreement(report)
	_check_automatic_completion(report)
	for part_id in [LIQUID_ID, TANK_ID, SOLID_ID, BOOSTER_ID, SMALL_TANK_ID]:
		GameData.parts_by_id.erase(part_id)


func _design() -> RocketDesign:
	var design := RocketDesign.new()
	design.add_stage(LIQUID_ID, TANK_ID)
	design.add_stage(SOLID_ID)
	design.add_stage(LIQUID_ID, TANK_ID)
	design.payload_part_ids.append("science_camera_basic")
	return design


func _check_handover(report: TestReport) -> void:
	var design: RocketDesign = _design()
	var vehicle: VehicleState = RocketModel.create_vehicle_state(design)
	var initial_mass_kilograms: float = RocketModel.total_mass_kilograms(vehicle)
	var capacity_meters_per_second: float = RocketModel.available_delta_v_meters_per_second(vehicle, design.stages[0].stage_id)
	var exact: BurnAllocation = SequentialPropulsion.apply_burn(vehicle.duplicate_vehicle_state(), capacity_meters_per_second)
	report.check(exact.stage_ids == [design.stages[0].stage_id], "exact liquid exhaustion leaves the next solid unlit")
	var requested_meters_per_second: float = capacity_meters_per_second + 10.0
	var allocation: BurnAllocation = SequentialPropulsion.apply_burn(vehicle, requested_meters_per_second)
	report.check(allocation.stage_ids == [design.stages[0].stage_id, design.stages[1].stage_id], "liquid-to-solid handover fires both stages in order")
	report.check(allocation.outcome.delta_v_delivered_meters_per_second > requested_meters_per_second, "solid overshoot is delivered rather than clipped")
	report.check_close(vehicle.propellant_kilograms_by_stage[design.stages[1].stage_id], 0.0, 0.0, "solid burns completely after liquid handover")
	report.check_close(vehicle.propellant_kilograms_by_stage[design.stages[2].stage_id], 100.0, 0.0, "overshoot leaves the following liquid stage untouched")
	report.check_close(RocketModel.total_mass_kilograms(vehicle),
			initial_mass_kilograms - allocation.outcome.propellant_used_kilograms - 25.0, 0.000001,
			"separation removes engine and tank dry mass after propellant use")
	report.check_close(allocation.stage_outcomes[1].mass_before_kilograms,
			initial_mass_kilograms - 100.0 - 15.0, 0.000001, "the solid accelerates the mass remaining after liquid-stage separation")
	var first_burn: BurnOutcome = allocation.stage_outcomes[0]
	var expected_delta_v_meters_per_second: float = 300.0 * 9.80665 * log(initial_mass_kilograms / (initial_mass_kilograms - 100.0))
	report.check_close(first_burn.delta_v_delivered_meters_per_second, expected_delta_v_meters_per_second, 0.000001,
			"discarded dry mass is excluded from the propulsive mass ratio")
	var saved_fuel: Dictionary = vehicle.propellant_kilograms_by_stage.duplicate()
	report.check(not SequentialPropulsion.apply_burn(vehicle, 0.0).outcome.did_fire
			and saved_fuel == vehicle.propellant_kilograms_by_stage, "zero demand ignites nothing")
	var failed: VehicleState = RocketModel.create_vehicle_state(design)
	failed.has_failed_by_stage[design.stages[0].stage_id] = true
	var blocked: BurnAllocation = SequentialPropulsion.apply_burn(failed, 10000.0)
	report.check(blocked.stage_ids.is_empty() and not failed.is_jettisoned_by_stage[design.stages[0].stage_id],
			"a failed attached stage blocks upper-stage ignition")
	var solids: VehicleState = RocketModel.create_vehicle_state(design)
	SequentialPropulsion.apply_burn(solids, capacity_meters_per_second)
	var failed_solid: VehicleState = solids.duplicate_vehicle_state()
	failed_solid.has_failed_by_stage[design.stages[1].stage_id] = true
	var blocked_solid: BurnAllocation = SequentialPropulsion.apply_burn(failed_solid, 100.0, true)
	report.check(not blocked_solid.is_satisfied and not blocked_solid.outcome.did_fire, "a failed solid pulse is blocked rather than treated as a zero-size success")
	var solid_pulse: BurnAllocation = SequentialPropulsion.apply_burn(solids, 100000.0, true)
	report.check(solid_pulse.stage_ids == [design.stages[1].stage_id] and solid_pulse.is_satisfied,
			"a direction-only solid pulse burns one whole motor")
	var whole: BurnAllocation = SequentialPropulsion.apply_burn(RocketModel.create_vehicle_state(design), 100000.0)
	report.check(whole.stage_ids.size() == 3 and not whole.is_satisfied, "a large liquid demand traverses the whole stack and reports its shortfall")


func _reference_plan() -> MissionPlan:
	var plan := MissionPlan.new()
	plan.launch_angle_radians = deg_to_rad(30.0)
	return plan


func _reference_design() -> RocketDesign:
	var design := RocketDesign.new()
	var unused_plan := MissionPlan.new()
	ExampleFlight.fill_reference_rocket(design, unused_plan)
	return design


func _check_ascent(report: TestReport) -> void:
	var body: Dictionary = GameData.body("earth")
	for mission in GameData.all_missions():
		var design: RocketDesign = _reference_design()
		var plan: MissionPlan = _reference_plan()
		var resolved: ResolvedPlan = PlanResolver.resolve(design, plan, mission)
		var ascent: AscentResult = resolved.summary.ascent
		report.check(ascent.did_reach_initial_orbit, "automatic reference ascent reaches " + str(mission["target"]["altitude_kilometers"]) + " km")
		if ascent.orbit_entry_state == null:
			continue
		var elements: OrbitElements = Kepler.elements_from_state(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], ascent.orbit_entry_state)
		report.check_close(elements.semi_major_axis_meters - float(body["radius_meters"]),
				1000.0 * float(mission["target"]["altitude_kilometers"]), 1.0, "automatic orbit altitude agrees with the mission")
		report.check(elements.eccentricity < 0.00000001, "liquid insertion produces a circular orbit")
		var stage_id: int = design.stages[1].stage_id
		report.check(ascent.vehicle_state.propellant_kilograms_by_stage[stage_id] > 0.0,
				"automatic insertion retains liquid fuel for manual pulses")
		var propagated: OrbitState = Kepler.propagate(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], ascent.orbit_entry_state, elements.period_seconds * 0.4)
		report.check_close(propagated.radius_meters(), elements.semi_major_axis_meters, 0.01, "forward propagation preserves the calculated circular orbit")
	var weak_design := RocketDesign.new()
	weak_design.add_stage(LIQUID_ID, TANK_ID)
	GameData.parts_by_id[LIQUID_ID]["stats"]["thrust_kilonewtons"] = 0.001
	var weak: AscentResult = AscentPlanner.resolve(weak_design, GameData.all_missions()[0], deg_to_rad(30.0))
	report.check(not weak.can_lift_off and weak.departure.stage_ids.is_empty(), "insufficient lift-off thrust does not manufacture an ascent")
	GameData.parts_by_id[LIQUID_ID]["stats"]["thrust_kilonewtons"] = 1000.0


func _check_three_stage_ascent(report: TestReport) -> void:
	var design := RocketDesign.new()
	var booster: Stage = design.add_stage(BOOSTER_ID)
	var second: Stage = design.add_stage("engine_liquid_small", "tank_aluminium_blowdown")
	var third: Stage = design.add_stage(LIQUID_ID, SMALL_TANK_ID)
	design.payload_part_ids.assign(ExampleFlight.PAYLOAD_PART_IDS)
	var ascent: AscentResult = AscentPlanner.resolve(design, GameData.all_missions()[0], deg_to_rad(30.0))
	report.check(ascent.did_reach_initial_orbit, "solid booster plus two liquid stages reaches the initial orbit")
	report.check(ascent.vehicle_state.is_jettisoned_by_stage[booster.stage_id], "the ascent fully consumes and separates the solid booster")
	report.check(ascent.propellant_used_by_stage_kilograms[second.stage_id] > 0.0
			and ascent.propellant_remaining_by_stage_kilograms[second.stage_id] > 0.0, "ascent uses only part of the second stage")
	report.check_close(ascent.propellant_used_by_stage_kilograms[third.stage_id], 0.0, 0.0, "third stage remains unused during ascent")
	report.check_close(ascent.propellant_remaining_by_stage_kilograms[third.stage_id], 5.0, 0.0, "third-stage propellant remains attached and full")


func _check_reassignment_and_reachability(report: TestReport) -> void:
	var body: Dictionary = GameData.body("earth")
	var radius_meters: float = float(body["radius_meters"]) + 400000.0
	var state: OrbitState = OrbitState.create(radius_meters, 0.0, 0.0,
			Kepler.circular_speed_meters_per_second(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], radius_meters))
	var design: RocketDesign = _design()
	var vehicle: VehicleState = RocketModel.create_vehicle_state(design)
	var plan := MissionPlan.new()
	var first := Pulse.new()
	first.pulse_id = 1
	first.polar_angle_radians = 0.0
	first.delta_v_along_velocity_meters_per_second = RocketModel.available_delta_v_meters_per_second(vehicle, design.stages[0].stage_id) + 10.0
	var second := Pulse.new()
	second.pulse_id = 2
	second.polar_angle_radians = 0.0
	second.delta_v_along_velocity_meters_per_second = 10.0
	plan.pulses.assign([first, second])
	var initial: ResolvedPlan = PlanResolver.resolve_remaining(body, state, vehicle, plan)
	report.check(initial.summary.pulse_allocations[1].stage_ids == [design.stages[2].stage_id], "a downstream pulse uses the stage following a liquid-to-solid burn")
	first.delta_v_along_velocity_meters_per_second = 10.0
	var edited: ResolvedPlan = PlanResolver.resolve_remaining(body, state, vehicle, plan)
	report.check(edited.summary.pulse_allocations[1].stage_ids == [design.stages[0].stage_id], "reducing an earlier pulse reassigns later pulses to the remaining liquid stage")
	report.check(edited.summary.pulse_allocations[0].before_state.time_seconds == edited.summary.pulse_allocations[1].before_state.time_seconds,
			"same-angle manual pulses fire at the same instant")
	var ballistic: OrbitState = Kepler.launch_state(body, PI / 2.0, 6000.0, deg_to_rad(30.0))
	first.extra_revolutions = 1
	var unreachable: ResolvedPlan = PlanResolver.resolve_remaining(body, ballistic, vehicle, plan)
	report.check(unreachable.trajectory.first_unreachable_pulse_index == 0, "impact before the requested crossing marks the first unreachable pulse")
	report.check(unreachable.summary.pulse_allocations[0].stage_ids.is_empty()
			and unreachable.summary.pulse_allocations[1].stage_ids.is_empty(), "unreachable and blocked pulses consume no fuel")
	report.check_close(unreachable.summary.mass_after_pulse_kilograms[1], RocketModel.total_mass_kilograms(vehicle), 0.0,
			"unreachable pulses do not discard stages")

	first.extra_revolutions = 0
	var impact_seconds: float = Kepler.seconds_until_impact(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], ballistic, OrbitModel.impact_radius_meters(body))
	var after_impact: OrbitState = Kepler.propagate(body[AscentPlanner.GRAVITATIONAL_PARAMETER_KEY], ballistic, impact_seconds + 0.0000005)
	first.polar_angle_radians = after_impact.polar_angle_radians()
	var late: ResolvedPlan = PlanResolver.resolve_remaining(body, ballistic, vehicle, plan)
	report.check(late.summary.pulse_allocations[0].stage_ids.is_empty(), "a pulse just after atmospheric impact consumes no propellant")


func _check_flight_agreement(report: TestReport) -> void:
	for mission in GameData.all_missions():
		var design: RocketDesign = _reference_design()
		var plan: MissionPlan = _reference_plan()
		var prediction: ResolvedPlan = PlanResolver.resolve(design, plan, mission)
		var ascent: AscentResult = prediction.summary.ascent
		var pulse := Pulse.new()
		pulse.pulse_id = 1
		pulse.polar_angle_radians = ascent.orbit_entry_state.polar_angle_radians()
		pulse.delta_v_along_velocity_meters_per_second = 20.0
		plan.pulses.append(pulse)
		prediction = PlanResolver.resolve(design, plan, mission)
		var fired: Array[int] = []
		var flight := Flight.new()
		flight.pulse_fired.connect(func(pulse_index: int, _outcome: BurnOutcome) -> void: fired.append(pulse_index))
		flight.start_flight(design, plan, mission, 1)
		flight.advance_simulation(ascent.orbit_entry_state.time_seconds)
		report.check(fired == [0], "automatic insertion preserves the first coincident manual pulse index")
		var expected: OrbitState = prediction.summary.pulse_allocations[0].after_state
		report.check_close(flight.craft_state.position_x_meters, expected.position_x_meters, 0.01, "live and predicted insertion positions agree")
		report.check_close(flight.craft_state.velocity_y_meters_per_second, expected.velocity_y_meters_per_second, 0.00001, "live and predicted manual-pulse velocities agree")
		report.check_close(RocketModel.total_mass_kilograms(flight.vehicle_state), prediction.summary.mass_after_pulse_kilograms[0], 0.000001,
				"live staging consumes predicted fuel exactly once")
		flight.free()


func _register_parts() -> void:
	GameData.register_part(_part(LIQUID_ID, "engine", 10.0, {"engine_type": "liquid", "specific_impulse_seconds": 300.0, "thrust_kilonewtons": 1000.0}))
	GameData.register_part(_part(TANK_ID, "tank", 5.0, {"propellant_capacity_kilograms": 100.0}))
	GameData.register_part(_part(SMALL_TANK_ID, "tank", 1.0, {"propellant_capacity_kilograms": 5.0}))
	GameData.register_part(_part(SOLID_ID, "engine", 10.0, {"engine_type": "solid", "specific_impulse_seconds": 200.0, "thrust_kilonewtons": 1000.0, "propellant_kilograms": 20.0}))
	var engine: Dictionary = GameData.part(ExampleFlight.FIRST_STAGE_ENGINE_PART_ID)
	var tank: Dictionary = GameData.part(ExampleFlight.FIRST_STAGE_TANK_PART_ID)
	var stats: Dictionary = engine["stats"].duplicate(true)
	stats["engine_type"] = "solid"
	stats["propellant_kilograms"] = tank["stats"]["propellant_capacity_kilograms"]
	GameData.register_part(_part(BOOSTER_ID, "engine", float(engine["dry_mass_kilograms"]) + float(tank["dry_mass_kilograms"]), stats))


func _part(part_id: String, category: String, dry_mass_kilograms: float, stats: Dictionary) -> Dictionary:
	return {"id": part_id, "name": part_id, "category": category, "dry_mass_kilograms": dry_mass_kilograms,
		"cost_million_usd": 0.0, "stats": stats, "source": "Synthetic T05 test fixture"}


func _check_automatic_completion(report: TestReport) -> void:
	var saved_mission: Dictionary = GameState.mission
	var saved_science: String = GameState.science_mission_id
	var mission: Dictionary = GameData.all_missions()[0]
	GameState.mission = mission
	GameState.science_mission_id = mission["science_missions"][0]["id"]
	for should_fail in [false, true]:
		var design: RocketDesign = _reference_design()
		if should_fail:
			design.stages.clear()
			design.add_stage("engine_solid_basic")
			design.payload_part_ids.assign(["science_camera_basic"])
		var plan: MissionPlan = _reference_plan()
		var results: Array[FlightResult] = []
		var flight := Flight.new()
		flight.flight_ended.connect(func(result: FlightResult) -> void: results.append(result))
		flight.start_flight(design, plan, mission, 1)
		for chunk_index in 100:
			if not results.is_empty():
				break
			flight.advance_simulation(500.0)
		report.check(results.size() == 1, "automatic flight ends exactly once within the bounded run")
		if not results.is_empty():
			var result: FlightResult = results[0]
			var no_quests: Array[Dictionary] = []
			var score: ScoreReport = Scoring.compute_score(mission, GameState.science_mission(), no_quests, design,
					RocketModel.total_cost_million_usd(design), mission["budget_million_usd"], result)
			if should_fail:
				report.check(result.end_reason == FlightResult.EndReason.LAUNCH_FAILURE and not result.did_reach_orbit,
						"an underpowered automatic solid ascent ends as launch failure")
				report.check_close(score.total_points, 0.0, 0.0, "automatic launch failure scores zero")
			else:
				report.check(result.end_reason == FlightResult.EndReason.MISSION_COMPLETED and result.did_reach_orbit,
						"the automatic reference flight completes its mission in orbit")
				report.check(result.data_delivered_megabits >= 5000.0 and score.total_points >= 90.0,
						"automatic ascent preserves a successful science mission and score")
		flight.free()
	GameState.mission = saved_mission
	GameState.science_mission_id = saved_science
