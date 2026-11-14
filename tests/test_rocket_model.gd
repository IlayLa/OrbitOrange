extends RefCounted
## Checks the rocket numbers of task T02: the rocket equation, the mass
## bookkeeping of burns and whole plans, design validation, the format of the
## parts catalogue, and the balance of the catalogue against the seed mission.

const TEST_PART_IDS: Array[String] = [
	"test_engine_liquid", "test_engine_weak", "test_engine_solid", "test_tank", "test_payload",
]
const REQUIRED_STATS_BY_CATEGORY := {
	"engine": ["engine_type", "specific_impulse_seconds", "thrust_kilonewtons"],
	"tank": ["propellant_capacity_kilograms", "pressurization"],
	"telemetry": [
		"channel", "range_kilometers", "noise_fraction", "updates_per_second",
		"resolution_level", "dropout_probability",
	],
	"science": ["power_watts", "data_rate_megabits_per_second", "science_value"],
}
const REQUIRED_PART_KEYS: Array[String] = [
	"id", "category", "name", "tier", "cost_million_usd", "dry_mass_kilograms",
	"icon_path", "tradeoff", "source", "is_approximate", "mission_fit", "stats",
]
const TELEMETRY_CHANNELS: Array[String] = [
	TelemetryFrame.CHANNEL_ALTITUDE_METERS, TelemetryFrame.CHANNEL_FUEL_KILOGRAMS,
	TelemetryFrame.CHANNEL_ATTITUDE_RADIANS, TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS,
	TelemetryFrame.CHANNEL_TEMPERATURE_KELVIN, "radar", "computer",
]
const STANDARD_GRAVITY := RocketModel.STANDARD_GRAVITY_METERS_PER_SECOND_SQUARED


func run_tests(report: TestReport) -> void:
	_check_catalogue_format(report)
	_check_balance(report)

	_register_test_parts()
	_check_rocket_equation(report)
	_check_two_stage_burn(report)
	_check_solid_motor(report)
	_check_liquid_engine_limits(report)
	_check_broken_and_weakened_stages(report)
	_check_plan_summary(report)
	_check_validation(report)
	for part_id in TEST_PART_IDS:
		GameData.parts_by_id.erase(part_id)


## Round-number parts: a 100 kg liquid engine (300 s, 30 kN), a 100 kg tank
## for 1000 kg, a 50 kg solid motor (250 s, 500 kg of propellant) and a
## 100 kg payload.
func _register_test_parts() -> void:
	_register("test_engine_liquid", "engine", 100.0, {
		"engine_type": "liquid", "specific_impulse_seconds": 300.0, "thrust_kilonewtons": 30.0})
	_register("test_engine_weak", "engine", 100.0, {
		"engine_type": "liquid", "specific_impulse_seconds": 300.0, "thrust_kilonewtons": 1.0})
	_register("test_engine_solid", "engine", 50.0, {
		"engine_type": "solid", "specific_impulse_seconds": 250.0, "thrust_kilonewtons": 20.0,
		"propellant_kilograms": 500.0})
	_register("test_tank", "tank", 100.0, {
		"propellant_capacity_kilograms": 1000.0, "pressurization": "regulated"})
	_register("test_payload", "science", 100.0, {
		"power_watts": 1.0, "data_rate_megabits_per_second": 1.0, "science_value": 1.0})


func _register(part_id: String, category: String, dry_mass_kilograms: float, stats: Dictionary) -> void:
	GameData.register_part({
		"id": part_id, "category": category, "name": part_id, "tier": 1,
		"cost_million_usd": 1.0, "dry_mass_kilograms": dry_mass_kilograms,
		"icon_path": "", "tradeoff": "", "source": "Test part.", "is_approximate": true,
		"mission_fit": {}, "stats": stats,
	})


## Two liquid stages of 1200 kg each under a 100 kg payload: 2500 kg in all.
func _two_stage_design() -> RocketDesign:
	var design := RocketDesign.new()
	design.add_stage("test_engine_liquid", "test_tank")
	design.add_stage("test_engine_liquid", "test_tank")
	design.payload_part_ids.append("test_payload")
	return design


func _pulse(stage_id: int, delta_v_meters_per_second: float) -> Pulse:
	var pulse := Pulse.new()
	pulse.stage_id = stage_id
	pulse.delta_v_along_velocity_meters_per_second = delta_v_meters_per_second
	return pulse


func _check_rocket_equation(report: TestReport) -> void:
	report.check_close(
			RocketModel.delta_v_from_rocket_equation(300.0, 3000.0, 2900.0), 99.7, 0.1,
			"100 kg of propellant at 300 s from 3000 kg gives about 99.7 m/s")
	report.check_close(
			RocketModel.delta_v_from_rocket_equation(300.0, 1000.0, 900.0), 310.0, 0.1,
			"100 kg of propellant at 300 s from 1000 kg gives about 310.0 m/s")
	var delta_v_meters_per_second: float = RocketModel.delta_v_from_rocket_equation(300.0, 3000.0, 2900.0)
	report.check_close(
			RocketModel.propellant_needed_for_delta_v(300.0, 3000.0, delta_v_meters_per_second), 100.0, 0.000001,
			"propellant_needed_for_delta_v is the inverse of the rocket equation")


func _check_two_stage_burn(report: TestReport) -> void:
	var design: RocketDesign = _two_stage_design()
	var vehicle_state: VehicleState = RocketModel.create_vehicle_state(design)
	report.check_close(
			RocketModel.total_mass_kilograms(vehicle_state), 2500.0, 0.000001,
			"the two-stage test rocket weighs 2500 kg on the pad")
	report.check_close(
			RocketModel.available_delta_v_meters_per_second(vehicle_state, 1),
			300.0 * STANDARD_GRAVITY * log(2500.0 / 1500.0), 0.000001,
			"stage 1 can deliver the rocket equation from 2500 kg to 1500 kg")
	report.check_close(
			RocketModel.available_delta_v_meters_per_second(vehicle_state, 2),
			300.0 * STANDARD_GRAVITY * log(1300.0 / 300.0), 0.000001,
			"stage 2 is rated with stage 1 already dropped: from 1300 kg to 300 kg")

	var outcome: BurnOutcome = RocketModel.apply_burn(vehicle_state, 2, 100.0)
	report.check(outcome.did_fire, "stage 2 fires")
	report.check(
			outcome.jettisoned_stage_ids.size() == 1 and outcome.jettisoned_stage_ids[0] == 1,
			"firing stage 2 reports stage 1 as dropped")
	report.check(vehicle_state.is_jettisoned_by_stage[1], "firing stage 2 marks stage 1 as dropped")
	report.check_close(outcome.mass_before_kilograms, 1300.0, 0.000001, "the burn starts from 1300 kg")
	report.check_close(
			outcome.mass_after_kilograms, 1300.0 - outcome.propellant_used_kilograms, 0.000001,
			"the mass after the burn is lower by the propellant used")
	report.check_close(
			RocketModel.total_mass_kilograms(vehicle_state), outcome.mass_after_kilograms, 0.000001,
			"the vehicle state has the mass the burn reports")
	report.check_close(outcome.delta_v_delivered_meters_per_second, 100.0, 0.000001, "the burn delivers the 100 m/s asked")
	var mass_flow_kilograms_per_second: float = 30000.0 / (300.0 * STANDARD_GRAVITY)
	report.check_close(
			outcome.burn_duration_seconds, outcome.propellant_used_kilograms / mass_flow_kilograms_per_second, 0.000001,
			"burn duration is propellant used divided by mass flow")
	report.check(
			RocketModel.available_delta_v_meters_per_second(vehicle_state, 1) == 0.0,
			"a dropped stage has no delta-v")
	report.check(not RocketModel.apply_burn(vehicle_state, 1, 100.0).did_fire, "a dropped stage does not fire")


func _check_solid_motor(report: TestReport) -> void:
	var design := RocketDesign.new()
	design.add_stage("test_engine_solid")
	design.payload_part_ids.append("test_payload")
	var vehicle_state: VehicleState = RocketModel.create_vehicle_state(design)
	var outcome: BurnOutcome = RocketModel.apply_burn(vehicle_state, 1, 1.0)
	report.check_close(outcome.propellant_used_kilograms, 500.0, 0.000001, "a solid motor burns everything whatever is requested")
	report.check_close(
			outcome.delta_v_delivered_meters_per_second, 250.0 * STANDARD_GRAVITY * log(650.0 / 150.0), 0.000001,
			"a solid motor delivers its full delta-v")
	report.check(vehicle_state.is_jettisoned_by_stage[1], "an empty stage is dropped")
	report.check(outcome.jettisoned_stage_ids.has(1), "the burn reports the emptied stage as dropped")
	report.check_close(outcome.mass_after_kilograms, 100.0, 0.000001, "only the payload is left after the motor is dropped")

	# A pulse with no direction cannot be flown, so a solid motor keeps its propellant.
	var unfired_state: VehicleState = RocketModel.create_vehicle_state(design)
	report.check(not RocketModel.apply_burn(unfired_state, 1, 0.0).did_fire, "a solid motor asked for nothing does not fire")
	report.check_close(
			unfired_state.propellant_kilograms_by_stage[1], 500.0, 0.000001,
			"a solid motor asked for nothing keeps its propellant")

	var no_direction_plan := MissionPlan.new()
	no_direction_plan.pulses.append(_pulse(1, 0.0))
	var no_direction_summary: PlanSummary = RocketModel.summarize_plan(design, no_direction_plan, 0.0)
	report.check(
			no_direction_summary.delta_v_delivered_by_pulse[0] == 0.0
			and no_direction_summary.delta_v_remaining_by_stage[1] > 0.0,
			"a solid pulse with no direction delivers nothing and leaves the motor full")
	report.check(
			no_direction_summary.warnings.any(func(sentence: String) -> bool: return sentence.contains("no direction")),
			"a solid pulse with no direction is reported")


func _check_liquid_engine_limits(report: TestReport) -> void:
	var design: RocketDesign = _two_stage_design()
	var plan := MissionPlan.new()
	plan.launch_stage_ids.append(1)
	plan.pulses.append(_pulse(2, 100.0))
	plan.pulses.append(_pulse(2, 99999.0))
	plan.pulses.append(_pulse(2, 50.0))
	var summary: PlanSummary = RocketModel.summarize_plan(design, plan, 0.0)
	var stage_two_delta_v: float = 300.0 * STANDARD_GRAVITY * log(1300.0 / 300.0)
	report.check(summary.is_pulse_affordable[0], "a pulse within the propellant is affordable")
	report.check_close(summary.delta_v_delivered_by_pulse[0], 100.0, 0.000001, "an affordable pulse delivers what was asked")
	report.check(not summary.is_pulse_affordable[1], "a liquid engine asked for more than it has is not affordable")
	report.check_close(
			summary.delta_v_delivered_by_pulse[1], stage_two_delta_v - 100.0, 0.000001,
			"a liquid engine asked for more than it has delivers what it has")
	report.check(
			not summary.is_pulse_affordable[2] and summary.delta_v_delivered_by_pulse[2] == 0.0,
			"a pulse on an empty stage delivers nothing")
	report.check(summary.reserve_delta_v_meters_per_second == 0.0, "nothing is in reserve after the tanks ran dry")
	report.check(summary.warnings.size() == 1, "the pulse on the empty stage is reported as one warning")


func _check_broken_and_weakened_stages(report: TestReport) -> void:
	var design: RocketDesign = _two_stage_design()
	var vehicle_state: VehicleState = RocketModel.create_vehicle_state(design)
	var healthy_delta_v: float = RocketModel.available_delta_v_meters_per_second(vehicle_state, 2)
	vehicle_state.specific_impulse_factor_by_stage[2] = 0.5
	report.check_close(
			RocketModel.available_delta_v_meters_per_second(vehicle_state, 2), healthy_delta_v * 0.5, 0.000001,
			"half the specific impulse gives half the delta-v")
	vehicle_state.has_failed_by_stage[2] = true
	report.check(RocketModel.available_delta_v_meters_per_second(vehicle_state, 2) == 0.0, "a failed stage has no delta-v")
	report.check(not RocketModel.apply_burn(vehicle_state, 2, 100.0).did_fire, "a failed stage does not fire")
	report.check(not vehicle_state.is_jettisoned_by_stage[1], "a burn that does not fire drops nothing")
	report.check(RocketModel.available_delta_v_meters_per_second(vehicle_state, 99) == 0.0, "an unknown stage has no delta-v")


func _check_plan_summary(report: TestReport) -> void:
	var design: RocketDesign = _two_stage_design()
	var plan := MissionPlan.new()
	plan.launch_stage_ids.append(1)
	plan.pulses.append(_pulse(2, 100.0))
	var stage_one_delta_v: float = 300.0 * STANDARD_GRAVITY * log(2500.0 / 1500.0)
	var stage_two_delta_v: float = 300.0 * STANDARD_GRAVITY * log(1300.0 / 300.0)

	var summary: PlanSummary = RocketModel.summarize_plan(design, plan, 500.0)
	report.check_close(summary.cost_million_usd, 5.0, 0.000001, "the summary has the cost of all five parts")
	report.check_close(summary.wet_mass_kilograms, 2500.0, 0.000001, "the summary has the wet mass")
	report.check_close(summary.dry_mass_kilograms, 500.0, 0.000001, "the summary has the dry mass")
	report.check_close(
			summary.total_delta_v_meters_per_second, stage_one_delta_v + stage_two_delta_v, 0.000001,
			"total delta-v is every stage fired completely, in order")
	report.check_close(
			summary.burnout_speed_meters_per_second, stage_one_delta_v - 500.0, 0.000001,
			"burnout speed is the launch stage's delta-v minus the launch loss")
	report.check_close(
			summary.delta_v_remaining_by_stage[2], stage_two_delta_v - 100.0, 0.000001,
			"stage 2 keeps what the pulse did not use")
	report.check(summary.delta_v_remaining_by_stage[1] == 0.0, "the launch stage has nothing left")
	report.check_close(
			summary.reserve_delta_v_meters_per_second, stage_two_delta_v - 100.0, 0.000001,
			"the reserve is the sum of what the stages have left")
	report.check(summary.warnings.is_empty(), "a sound design and plan give no warnings")

	var huge_loss_summary: PlanSummary = RocketModel.summarize_plan(design, plan, 99999.0)
	report.check(huge_loss_summary.burnout_speed_meters_per_second == 0.0, "burnout speed is never below zero")

	var no_launch_summary: PlanSummary = RocketModel.summarize_plan(design, MissionPlan.new(), 500.0)
	report.check(
			no_launch_summary.warnings.has("No stage fires at launch."),
			"a plan without a launch stage is reported")

	# Upper stage listed first: it drops stage 1, which then cannot fire.
	var upside_down_plan := MissionPlan.new()
	upside_down_plan.launch_stage_ids.append(2)
	upside_down_plan.launch_stage_ids.append(1)
	var upside_down_summary: PlanSummary = RocketModel.summarize_plan(design, upside_down_plan, 0.0)
	report.check(
			upside_down_summary.warnings.size() == 1
			and upside_down_summary.warnings[0].begins_with(RocketModel.WARNING_PREFIX)
			and upside_down_summary.warnings[0].contains("Stage 1"),
			"a launch stage that is dropped before it fires is reported as a warning")

	var unknown_launch_plan := MissionPlan.new()
	unknown_launch_plan.launch_stage_ids.append(1)
	unknown_launch_plan.launch_stage_ids.append(99)
	var unknown_launch_summary: PlanSummary = RocketModel.summarize_plan(design, unknown_launch_plan, 0.0)
	report.check(
			unknown_launch_summary.warnings.size() == 1
			and unknown_launch_summary.warnings[0].contains("not part of the rocket"),
			"a launch stage the rocket does not have is reported")


func _check_validation(report: TestReport) -> void:
	report.check(
			RocketModel.validate_design(RocketDesign.new()).has("The rocket has no engine."),
			"an empty design has no engine")

	var tankless_design := RocketDesign.new()
	tankless_design.add_stage("test_engine_liquid")
	report.check(
			RocketModel.blocking_problems(tankless_design).has("Stage 1 has a liquid engine but no tank."),
			"a liquid engine without a tank blocks the launch")

	var wrong_parts_design := RocketDesign.new()
	wrong_parts_design.add_stage("test_tank", "test_tank")
	wrong_parts_design.add_stage("test_engine_solid", "test_tank")
	wrong_parts_design.add_stage("test_engine_liquid", "test_payload")
	wrong_parts_design.payload_part_ids.append("test_tank")
	report.check(
			RocketModel.blocking_problems(wrong_parts_design).size() == 4,
			"each wrongly used part gives one sentence")

	var weak_design := RocketDesign.new()
	var weak_stage: Stage = weak_design.add_stage("test_engine_weak", "test_tank")
	var weak_plan := MissionPlan.new()
	weak_plan.launch_stage_ids.append(weak_stage.stage_id)
	var weak_warnings: Array[String] = RocketModel.summarize_plan(weak_design, weak_plan, 0.0).warnings
	report.check(
			weak_warnings.size() == 1 and weak_warnings[0].begins_with(RocketModel.WARNING_PREFIX),
			"thrust below the weight on the pad gives a warning")
	report.check(
			RocketModel.blocking_sentences(weak_warnings).is_empty(),
			"the thrust warning does not block the launch")
	report.check(
			RocketModel.validate_design(_two_stage_design()).is_empty(),
			"a sound design has no problems")

	# A weak bottom stage that is not fired at launch: the check uses the stage
	# that really fires first, which lifts only itself and what is above it.
	var weak_bottom_design := RocketDesign.new()
	weak_bottom_design.add_stage("test_engine_weak", "test_tank")
	var strong_upper_stage: Stage = weak_bottom_design.add_stage("test_engine_liquid", "test_tank")
	var upper_first_plan := MissionPlan.new()
	upper_first_plan.launch_stage_ids.append(strong_upper_stage.stage_id)
	report.check(
			RocketModel.summarize_plan(weak_bottom_design, upper_first_plan, 0.0).warnings.is_empty(),
			"the thrust check uses the first stage that fires at launch, not the bottom stage")

	var engineless_design := RocketDesign.new()
	var engineless_stage: Stage = engineless_design.add_stage("", "test_tank")
	var engineless_plan := MissionPlan.new()
	engineless_plan.launch_stage_ids.append(engineless_stage.stage_id)
	var engineless_warnings: Array[String] = RocketModel.summarize_plan(engineless_design, engineless_plan, 0.0).warnings
	report.check(
			not engineless_warnings.any(func(sentence: String) -> bool: return sentence.contains("kilonewtons")),
			"a stage without an engine gives no thrust warning on top of its blocking problem")

	var mixed_sentences: Array[String] = ["Stage 1 has no engine.", RocketModel.WARNING_PREFIX + " advice."]
	report.check(
			RocketModel.blocking_sentences(mixed_sentences).size() == 1
			and RocketModel.blocking_sentences(mixed_sentences)[0] == "Stage 1 has no engine.",
			"blocking_sentences drops the warnings and keeps the rest")


func _check_catalogue_format(report: TestReport) -> void:
	var part_count_by_category := {}
	for part_id: String in GameData.parts_by_id:
		var part: Dictionary = GameData.parts_by_id[part_id]
		var missing_keys: Array[String] = []
		for key in REQUIRED_PART_KEYS:
			if not part.has(key):
				missing_keys.append(key)
		var category: String = part.get("category", "")
		var stats: Dictionary = part.get("stats", {})
		for key: String in REQUIRED_STATS_BY_CATEGORY.get(category, ["unknown category"]):
			if not stats.has(key):
				missing_keys.append("stats." + key)
		if stats.get("engine_type", "") == "solid" and not stats.has("propellant_kilograms"):
			missing_keys.append("stats.propellant_kilograms")
		report.check(
				missing_keys.is_empty(),
				"part \"%s\" has every required key for its category (missing: %s)" % [part_id, missing_keys])
		report.check(FileAccess.file_exists(part.get("icon_path", "")), "part \"%s\" has an icon file" % part_id)
		var tier: int = part.get("tier", 0)
		report.check(tier >= 1 and tier <= 3, "part \"%s\" has a tier from 1 to 3" % part_id)
		report.check(part.get("source", "") != "", "part \"%s\" names its source" % part_id)
		if category == "telemetry":
			report.check(
					TELEMETRY_CHANNELS.has(stats.get("channel", "")),
					"part \"%s\" uses a known telemetry channel" % part_id)
		part_count_by_category[category] = part_count_by_category.get(category, 0) + 1
	for category: String in REQUIRED_STATS_BY_CATEGORY:
		report.check(part_count_by_category.get(category, 0) >= 5, "the catalogue has at least five %s parts" % category)


## The catalogue against the seed mission: one affordable design reaches the
## target orbit and one obvious cheap design does not. Orbits belong to task
## T01; here the needed speeds come straight from the vis-viva equation.
func _check_balance(report: TestReport) -> void:
	var mission: Dictionary = GameData.all_missions()[0]
	var body: Dictionary = GameData.body(mission["body_id"])
	var gravitational_parameter: float = body["gravitational_parameter_cubic_meters_per_second_squared"]
	var surface_radius_meters: float = body["radius_meters"]
	var target_radius_meters: float = surface_radius_meters + mission["target"]["altitude_kilometers"] * 1000.0
	var launch_loss_meters_per_second: float = mission["launch_loss_meters_per_second"]
	var budget_million_usd: float = mission["budget_million_usd"]

	# Speed lost climbing from the surface to the target altitude, squared.
	var climb_speed_squared: float = 2.0 * gravitational_parameter * (1.0 / surface_radius_meters - 1.0 / target_radius_meters)
	# Slower than this at burnout and the craft never reaches the target altitude.
	var lowest_burnout_speed: float = sqrt(climb_speed_squared)
	# A horizontal burnout at this speed tops out exactly at the target
	# altitude; anything slower can reach it with a steeper launch angle.
	var highest_burnout_speed: float = sqrt(
			2.0 * gravitational_parameter
			* (1.0 / surface_radius_meters - 1.0 / (surface_radius_meters + target_radius_meters)))
	var circular_speed: float = sqrt(gravitational_parameter / target_radius_meters)

	var good_design := RocketDesign.new()
	var booster_stage: Stage = good_design.add_stage("engine_liquid_basic", "tank_aluminium_basic")
	var upper_stage: Stage = good_design.add_stage("engine_liquid_small", "tank_aluminium_blowdown")
	good_design.payload_part_ids.append("science_camera_basic")
	good_design.payload_part_ids.append("telemetry_altimeter_basic")
	var good_plan := MissionPlan.new()
	good_plan.launch_stage_ids.append(booster_stage.stage_id)
	var launch_summary: PlanSummary = RocketModel.summarize_plan(good_design, good_plan, launch_loss_meters_per_second)
	var burnout_speed: float = launch_summary.burnout_speed_meters_per_second
	report.check(
			burnout_speed > lowest_burnout_speed and burnout_speed <= highest_burnout_speed,
			"the reference design burns out fast enough to coast up to the target altitude (%.0f m/s)" % burnout_speed)
	# Speed at the top of the coast, then the pulse that makes the orbit circular.
	var speed_at_target_altitude: float = sqrt(maxf(0.0, burnout_speed * burnout_speed - climb_speed_squared))
	var circularization_delta_v: float = circular_speed - speed_at_target_altitude
	good_plan.pulses.append(_pulse(upper_stage.stage_id, circularization_delta_v))
	var good_summary: PlanSummary = RocketModel.summarize_plan(good_design, good_plan, launch_loss_meters_per_second)
	report.check(
			good_summary.is_pulse_affordable[0],
			"the reference design can afford the %.0f m/s pulse that circularizes at the target" % circularization_delta_v)
	report.check(
			good_summary.cost_million_usd <= budget_million_usd,
			"the reference design costs %.1f million USD, within the budget" % good_summary.cost_million_usd)
	report.check(good_summary.warnings.is_empty(), "the reference design has no warnings")
	report.check(
			good_summary.reserve_delta_v_meters_per_second >= 100.0,
			"the reference design keeps a reserve (%.0f m/s)" % good_summary.reserve_delta_v_meters_per_second)

	var cheap_design := RocketDesign.new()
	var solid_stage: Stage = cheap_design.add_stage("engine_solid_basic")
	cheap_design.payload_part_ids.append("science_camera_basic")
	var cheap_plan := MissionPlan.new()
	cheap_plan.launch_stage_ids.append(solid_stage.stage_id)
	var cheap_summary: PlanSummary = RocketModel.summarize_plan(cheap_design, cheap_plan, launch_loss_meters_per_second)
	report.check(
			cheap_summary.cost_million_usd < good_summary.cost_million_usd,
			"the single solid motor is the cheaper design")
	report.check(
			cheap_summary.burnout_speed_meters_per_second < highest_burnout_speed
			and cheap_summary.reserve_delta_v_meters_per_second == 0.0,
			"the single solid motor falls back: it is below orbital speed with nothing left to circularize")

	var skeleton_design := RocketDesign.new()
	var only_stage: Stage = skeleton_design.add_stage("engine_liquid_basic", "tank_aluminium_basic")
	skeleton_design.payload_part_ids.append("science_camera_basic")
	var skeleton_plan := MissionPlan.new()
	skeleton_plan.launch_stage_ids.append(only_stage.stage_id)
	report.check(
			RocketModel.summarize_plan(skeleton_design, skeleton_plan, launch_loss_meters_per_second)
			.burnout_speed_meters_per_second > lowest_burnout_speed,
			"the planning console's default rocket leaves the ground")
