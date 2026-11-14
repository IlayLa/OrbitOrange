class_name ExampleFlight
extends RefCounted
## A worked example that reaches orbit: T02's reference rocket, the launch angle
## whose apoapsis is at the mission's target altitude, and one pulse at that
## apoapsis that makes the orbit circular. The stub planning screen uses it for
## "Build example rocket", and the integration test flies it from the pad to a
## score. Added by T09. Static functions only; it keeps no state.

const FIRST_STAGE_ENGINE_PART_ID := "engine_liquid_basic"
const FIRST_STAGE_TANK_PART_ID := "tank_aluminium_basic"
const SECOND_STAGE_ENGINE_PART_ID := "engine_liquid_small"
const SECOND_STAGE_TANK_PART_ID := "tank_aluminium_blowdown"
const PAYLOAD_PART_IDS: Array[String] = ["science_camera_basic", "telemetry_altimeter_basic"]
## The search stays strictly inside these angles: a vertical launch (90 degrees)
## and a horizontal launch (0 degrees) are degenerate.
const LOWEST_LAUNCH_ANGLE_DEGREES := 1.0
const HIGHEST_LAUNCH_ANGLE_DEGREES := 89.0
## 60 halvings shrink the 88 degree interval far below floating point resolution.
const BISECTION_ITERATION_COUNT := 60


## Replaces the stages and payload of the design with the reference rocket and
## sets the plan to match: the first stage fires at launch, the launch angle puts
## the apoapsis at the mission's target altitude, and one pulse of the second
## stage at the apoapsis makes the orbit circular. The existing pulses and launch
## stages of the plan are replaced. Does nothing to GameState.
static func fill_reference_flight(design: RocketDesign, plan: MissionPlan, mission: Dictionary) -> void:
	fill_reference_rocket(design, plan)
	plan.launch_angle_radians = find_launch_angle_radians(design, plan, mission)
	plan.pulses.clear()
	plan.pulses.append(create_circularizing_pulse(design, plan, mission))


## Replaces the stages and payload of the design with the reference rocket (16.5
## million USD) and makes its first stage the only launch stage of the plan. The
## launch angle and the pulses of the plan are left alone.
static func fill_reference_rocket(design: RocketDesign, plan: MissionPlan) -> void:
	design.stages.clear()
	design.payload_part_ids.clear()
	var first_stage: Stage = design.add_stage(FIRST_STAGE_ENGINE_PART_ID, FIRST_STAGE_TANK_PART_ID)
	design.add_stage(SECOND_STAGE_ENGINE_PART_ID, SECOND_STAGE_TANK_PART_ID)
	design.payload_part_ids.append_array(PAYLOAD_PART_IDS)
	plan.launch_stage_ids.clear()
	plan.launch_stage_ids.append(first_stage.stage_id)


## The launch angle in radians above the horizontal whose orbit has its apoapsis
## at the mission's target altitude, found by bisection between 1 and 89 degrees
## (the apoapsis rises with the angle). The design and the launch stages of the
## plan decide the burnout speed. When the target is out of reach, the result is
## the nearest end of the interval.
static func find_launch_angle_radians(design: RocketDesign, plan: MissionPlan, mission: Dictionary) -> float:
	var body: Dictionary = GameData.body(mission.get("body_id", "earth"))
	var target_apoapsis_radius_meters: float = (
			float(body["radius_meters"]) + 1000.0 * float(mission["target"]["altitude_kilometers"]))
	var burnout_speed_meters_per_second: float = _burnout_speed_meters_per_second(design, plan, mission)
	var launch_site_angle_radians: float = _launch_site_angle_radians(mission)
	var lowest_angle_radians: float = deg_to_rad(LOWEST_LAUNCH_ANGLE_DEGREES)
	var highest_angle_radians: float = deg_to_rad(HIGHEST_LAUNCH_ANGLE_DEGREES)
	for iteration_index in BISECTION_ITERATION_COUNT:
		var middle_angle_radians: float = 0.5 * (lowest_angle_radians + highest_angle_radians)
		var apoapsis_radius_meters: float = launch_apoapsis_radius_meters(
				body, launch_site_angle_radians, burnout_speed_meters_per_second, middle_angle_radians)
		if apoapsis_radius_meters < target_apoapsis_radius_meters:
			lowest_angle_radians = middle_angle_radians
		else:
			highest_angle_radians = middle_angle_radians
	return 0.5 * (lowest_angle_radians + highest_angle_radians)


## Distance from the body's centre of the apoapsis reached after burnout at the
## given speed and launch angle, in meters. INF when the path is open.
static func launch_apoapsis_radius_meters(
		body: Dictionary,
		launch_site_angle_radians: float,
		burnout_speed_meters_per_second: float,
		launch_angle_radians: float) -> float:
	var launch_state: OrbitState = Kepler.launch_state(
			body, launch_site_angle_radians, burnout_speed_meters_per_second, launch_angle_radians)
	var elements: OrbitElements = Kepler.elements_from_state(
			body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY], launch_state)
	return elements.apoapsis_radius_meters


## The pulse that makes the orbit circular, for the launch angle already set in
## the plan: the second stage fires along the velocity at the apoapsis, by
## sqrt(gravitational_parameter / apoapsis radius) minus the speed there. The
## launch is counter-clockwise, so the apoapsis lies in the direction of the
## argument of periapsis plus PI. The pulse is not added to the plan.
static func create_circularizing_pulse(design: RocketDesign, plan: MissionPlan, mission: Dictionary) -> Pulse:
	var body: Dictionary = GameData.body(mission.get("body_id", "earth"))
	var gravitational_parameter: float = body[OrbitModel.GRAVITATIONAL_PARAMETER_KEY]
	var launch_state: OrbitState = Kepler.launch_state(
			body,
			_launch_site_angle_radians(mission),
			_burnout_speed_meters_per_second(design, plan, mission),
			plan.launch_angle_radians)
	var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, launch_state)
	var apoapsis_radius_meters: float = elements.apoapsis_radius_meters
	var speed_at_apoapsis_meters_per_second: float = absf(Kepler.signed_angular_momentum(launch_state)) / apoapsis_radius_meters
	var pulse := Pulse.new()
	pulse.pulse_id = plan.next_free_pulse_id()
	pulse.stage_id = design.stages[design.stages.size() - 1].stage_id
	pulse.polar_angle_radians = fposmod(elements.argument_of_periapsis_radians + PI, TAU)
	pulse.delta_v_along_velocity_meters_per_second = (
			Kepler.circular_speed_meters_per_second(gravitational_parameter, apoapsis_radius_meters)
			- speed_at_apoapsis_meters_per_second)
	return pulse


static func _burnout_speed_meters_per_second(design: RocketDesign, plan: MissionPlan, mission: Dictionary) -> float:
	var launch_loss_meters_per_second: float = mission.get("launch_loss_meters_per_second", 0.0)
	return RocketModel.summarize_plan(design, plan, launch_loss_meters_per_second).burnout_speed_meters_per_second


static func _launch_site_angle_radians(mission: Dictionary) -> float:
	var launch_site: Dictionary = mission.get("launch_site", {})
	return deg_to_rad(launch_site.get("polar_angle_degrees", 90.0))
