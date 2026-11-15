extends RefCounted
## Scenarios promise observable outcomes; verify the same fixtures used by the demo.

const Scenarios = preload("res://scripts/orbit/planning/T05Scenarios.gd")
const Flight = preload("res://autoload/FlightSimulation.gd")
const OverlayScene = preload("res://scenes/events/EmergencyOverlay.tscn")


func run_tests(report: TestReport) -> void:
	var mission: Dictionary = GameData.all_missions()[0]
	for scenario in Scenarios.CASES:
		var fixture: Dictionary = Scenarios.create(scenario["id"], mission)
		var design: RocketDesign = fixture["design"]
		var plan: MissionPlan = fixture["plan"]
		var resolved := PlanResolver.resolve(design, plan, mission)
		var ascent: AscentResult = resolved.summary.ascent
		report.check(RocketModel.validate_design(design).is_empty(), scenario["id"] + " uses a valid catalogue rocket")
		match scenario["id"]:
			"three-stage":
				report.check(ascent.did_reach_initial_orbit, "three-stage preset reaches orbit")
				report.check(ascent.vehicle_state.is_jettisoned_by_stage[design.stages[0].stage_id], "three-stage preset separates the spent solid")
				report.check(ascent.propellant_used_by_stage_kilograms[design.stages[1].stage_id] > 0.0
						and ascent.propellant_remaining_by_stage_kilograms[design.stages[1].stage_id] > 0.0, "three-stage preset partially consumes stage 2")
				report.check_close(ascent.propellant_used_by_stage_kilograms[design.stages[2].stage_id], 0.0, 0.0, "three-stage preset retains all stage 3 fuel")
			"late-solid":
				report.check(ascent.propellant_used_by_stage_kilograms[design.stages[2].stage_id] == 0.0, "late-solid preset reserves the motor through ascent")
				report.check(resolved.summary.pulse_allocations[0].stage_ids == [design.stages[1].stage_id], "late-solid pulse 1 drains only the liquid stage")
				report.check(resolved.summary.pulse_allocations[1].stage_ids == [design.stages[2].stage_id], "late-solid pulse 2 fires the next solid")
				report.check_close(resolved.summary.pulse_allocations[1].outcome.propellant_used_kilograms,
						RocketModel.full_propellant_kilograms(design.stages[2]), 0.000001, "later solid pulse consumes its entire motor")
			"handover":
				var burn: BurnAllocation = resolved.summary.pulse_allocations[0]
				report.check(burn.stage_ids == [design.stages[1].stage_id, design.stages[2].stage_id], "handover preset burns liquid then solid in one pulse")
				report.check(burn.outcome.delta_v_delivered_meters_per_second > burn.requested_delta_v_meters_per_second + 10.0, "handover preset exposes solid overshoot")
				report.check(resolved.trajectory.status == Trajectory.Status.ESCAPE, "handover preset predicts the actual escape")
			"impact":
				report.check(not ascent.did_reach_initial_orbit and resolved.trajectory.status == Trajectory.Status.IMPACT, "short-ascent preset predicts impact")
			"escape":
				report.check(resolved.trajectory.status == Trajectory.Status.ESCAPE and not resolved.summary.is_pulse_affordable[0], "excessive-demand preset predicts actual escape and shortfall")
			"unreachable":
				report.check(resolved.trajectory.first_unreachable_pulse_index == 1, "unreachable preset blocks the downstream pulse")
				report.check(resolved.summary.pulse_allocations[1].stage_ids.is_empty(), "unreachable preset spends no fuel on pulse 2")
				report.check_close(resolved.summary.mass_after_pulse_kilograms[1], resolved.summary.mass_after_pulse_kilograms[0], 0.0, "unreachable pulse preserves mass")
			"no-liftoff":
				report.check(not ascent.can_lift_off and ascent.departure.stage_ids.is_empty(), "weak-thrust preset blocks ignition")
			_:
				report.check(ascent.did_reach_initial_orbit, scenario["id"] + " starts with a usable orbit")
	_check_automatic_emergency(report, mission, false)
	_check_automatic_emergency(report, mission, true)


func _check_automatic_emergency(report: TestReport, mission: Dictionary, starts_on_solid: bool) -> void:
	var fixture: Dictionary = Scenarios.create("late-solid", mission)
	var design: RocketDesign = fixture["design"]
	var plan: MissionPlan = fixture["plan"]
	if starts_on_solid:
		plan.pulses.resize(1)
	else:
		plan.pulses.clear()
	var resolved := PlanResolver.resolve(design, plan, mission)
	var start_seconds: float = resolved.summary.pulse_allocations[0].after_state.time_seconds if starts_on_solid else resolved.summary.ascent.orbit_entry_state.time_seconds
	var flight := Flight.new()
	flight.start_flight(design, plan, mission, 7)
	flight.advance_simulation(start_seconds)
	report.check(flight.uses_automatic_staging(), "emergency integration reads the actual flight's staging mode")
	var current := SequentialPropulsion.current_stage(flight.vehicle_state)
	var demand := 1.0 if starts_on_solid else RocketModel.available_delta_v_meters_per_second(flight.vehicle_state, current.stage_id) + 10.0
	# Deliberately identify an unavailable stage: automatic execution must derive the correct one.
	var pulse := EmergencyManeuver.create_pulse(design.stages[0].stage_id, 180.0, demand)
	var body: Dictionary = GameData.body(mission["body_id"])
	var saved_fuel := flight.vehicle_state.propellant_kilograms_by_stage.duplicate()
	var saved_mass := RocketModel.total_mass_kilograms(flight.vehicle_state)
	var preview := EmergencyManeuver.preview_automatic_trajectory(body, flight.craft_state, flight.vehicle_state, pulse)
	report.check(preview != null, "automatic emergency preview accepts the current sequential stack")
	report.check(saved_fuel == flight.vehicle_state.propellant_kilograms_by_stage, "emergency preview preserves live propellant")
	report.check_close(RocketModel.total_mass_kilograms(flight.vehicle_state), saved_mass, 0.0, "emergency preview preserves attached mass")
	if preview != null:
		var expected: OrbitState = preview.final_segment().start_state
		var outcome: BurnOutcome = flight.apply_emergency_pulse(pulse)
		report.check(outcome.did_fire, "automatic live emergency fires despite a stale explicit stage id")
		report.check_close(flight.craft_state.velocity_x_meters_per_second, expected.velocity_x_meters_per_second, 0.000001, "automatic emergency preview and execution agree on x velocity")
		report.check_close(flight.craft_state.velocity_y_meters_per_second, expected.velocity_y_meters_per_second, 0.000001, "automatic emergency preview and execution agree on y velocity")
	flight.free()

	# Exercise the real overlay against a fresh automatic flight, including direction-only solids.
	flight = Flight.new()
	flight.start_flight(design, plan, mission, 7)
	flight.advance_simulation(start_seconds)
	var threat := Threat.new()
	threat.state = flight.craft_state.duplicate_state()
	threat.collision_radius_meters = 100.0
	var overlay: Control = OverlayScene.instantiate()
	overlay.open_alert(flight, mission, body, "Integration scenario", threat, start_seconds + 60.0,
			func(candidate: Pulse) -> bool: return flight.apply_emergency_pulse(candidate).did_fire, Callable())
	GameState.add_child(overlay)
	var selector: OptionButton = overlay.get_node("%Stage")
	report.check(selector.item_count == 1 and selector.get_selected_id() == current.stage_id, "automatic emergency overlay offers only the current stage")
	var strength: SpinBox = overlay.get_node("%Strength")
	report.check(strength.editable != starts_on_solid, "automatic emergency magnitude is editable only for a liquid start")
	report.check(not overlay.get_node("%Execute").disabled, "automatic emergency overlay can execute its sequential preview")
	_check_overlay_gestures(report, overlay, starts_on_solid)
	overlay.call("_execute_maneuver")
	report.check(not overlay.visible, "successful automatic emergency closes the overlay")
	if not starts_on_solid:
		var blocked_stage := SequentialPropulsion.current_stage(flight.vehicle_state)
		flight.vehicle_state.has_failed_by_stage[blocked_stage.stage_id] = true
		var before_blocked_preview := flight.vehicle_state.propellant_kilograms_by_stage.duplicate()
		report.check(EmergencyManeuver.preview_automatic_trajectory(body, flight.craft_state, flight.vehicle_state, pulse) == null,
				"failed current stage blocks an automatic preview despite upper-stage fuel")
		overlay.call("_refresh_stages", 8.0)
		report.check(selector.disabled and overlay.get("_selected_stage_id") == -1, "automatic emergency overlay cannot select an upper stage through a failed stage")
		report.check(overlay.get_node("%Execute").disabled, "blocked automatic emergency disables execution")
		report.check(before_blocked_preview == flight.vehicle_state.propellant_kilograms_by_stage, "blocked preview preserves every stage's fuel")
	overlay.free()
	flight.free()


## The overlay aims like the orbit planning screen: a slingshot pull, a direct
## drag from the arrow tip, the same length scale, and Escape to undo. Each drag
## starts with a real press through the map's input handler.
func _check_overlay_gestures(report: TestReport, overlay: Control, is_solid: bool) -> void:
	var view: OrbitView = overlay.get("_view")
	var craft: OrbitState = overlay.get("_craft")
	var angle: SpinBox = overlay.get_node("%Angle")
	var strength: SpinBox = overlay.get_node("%Strength")
	var origin_pixels: Vector2 = view.world_to_screen(craft.position_x_meters, craft.position_y_meters)
	var first_tip_pixels: Vector2 = overlay.call("_arrow_tip")
	report.check(overlay.call("_pick_part", origin_pixels) == "craft", "emergency: pressing the craft grabs the burn's base")
	report.check(overlay.call("_pick_part", origin_pixels + (first_tip_pixels - origin_pixels).normalized() * 4.0) == "craft",
			"emergency: a short default arrow does not hide the craft (the nearer part wins)")
	var probe := Pulse.new()
	probe.set_delta_v_from_angle(45.0, 1.0)
	var forward_pixels: Vector2 = PulseGeometry.arrow_direction(view, craft, probe)
	var saved_angle_degrees: float = angle.value
	var saved_strength_meters_per_second: float = strength.value
	var target_meters_per_second: float = strength.max_value * 0.5
	var pull_length_pixels: float = PulseGeometry.arrow_length_pixels(target_meters_per_second)

	# A press away from the craft still starts a slingshot, pulled from the press point.
	var press_pixels: Vector2 = origin_pixels + Vector2(40, 30)
	overlay.call("_on_map_input", _left_button(press_pixels, true))
	report.check(overlay.get("_drag_mode") == "slingshot", "emergency: pressing the map starts a slingshot")
	overlay.call("_update_drag", press_pixels + Vector2(3, 0))
	report.check_close(angle.value, saved_angle_degrees, 0.0, "emergency: a pull inside the threshold leaves the burn alone")
	overlay.call("_update_drag", press_pixels - forward_pixels * pull_length_pixels)
	report.check_close(angle.value, 45.0, 0.5, "emergency: pulling back burns the opposite way")
	if not is_solid:
		report.check_close(strength.value, target_meters_per_second, 0.05, "emergency: the pull length sets the strength on the planning scale")
	var escape := InputEventKey.new()
	escape.keycode = KEY_ESCAPE
	escape.pressed = true
	overlay.call("_input", escape)
	report.check(overlay.get("_drag_mode") == "", "emergency: Escape ends the drag")
	report.check_close(angle.value, saved_angle_degrees, 0.0, "emergency: Escape restores the angle")
	report.check_close(strength.value, saved_strength_meters_per_second, 0.0, "emergency: Escape restores the strength")

	overlay.call("_on_map_input", _left_button(overlay.call("_arrow_tip"), true))
	report.check(overlay.get("_drag_mode") == "arrow", "emergency: pressing the arrow tip grabs it")
	overlay.call("_update_drag", origin_pixels + forward_pixels * pull_length_pixels)
	report.check_close(angle.value, 45.0, 0.5, "emergency: dragging the arrow tip points the burn at the cursor")
	overlay.call("_input", _left_button(origin_pixels, false))
	report.check(overlay.get("_drag_mode") == "", "emergency: releasing the button ends the drag")
	# Hand the scenario back the maneuver it set up.
	angle.value = saved_angle_degrees
	strength.value = saved_strength_meters_per_second


func _left_button(position_pixels: Vector2, is_pressed: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = is_pressed
	event.position = position_pixels
	return event
