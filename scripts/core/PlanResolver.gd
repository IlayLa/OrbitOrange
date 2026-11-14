class_name PlanResolver
extends RefCounted
## Turns a rocket design and a mission plan into the two things every screen
## needs: the mass bookkeeping (PlanSummary) and the flight path (Trajectory).
##
## This is the only place where RocketModel and OrbitModel meet. RocketModel
## decides how much velocity change each pulse can really deliver; OrbitModel
## then flies those delivered burns. Owned by the integrator.


static func resolve(design: RocketDesign, plan: MissionPlan, mission: Dictionary) -> ResolvedPlan:
	var body_id: String = mission.get("body_id", "earth")
	var body: Dictionary = GameData.body(body_id)
	var launch_loss_meters_per_second: float = mission.get("launch_loss_meters_per_second", 0.0)

	var summary: PlanSummary = RocketModel.summarize_plan(design, plan, launch_loss_meters_per_second)

	var launch_site: Dictionary = mission.get("launch_site", {})
	var launch_site_angle_degrees: float = launch_site.get("polar_angle_degrees", 90.0)
	var launch_state: OrbitState = Kepler.launch_state(
			body,
			deg_to_rad(launch_site_angle_degrees),
			summary.burnout_speed_meters_per_second,
			plan.launch_angle_radians)

	var resolved_burns: Array[ResolvedBurn] = create_resolved_burns(plan, summary)

	var resolved_plan := ResolvedPlan.new()
	resolved_plan.summary = summary
	resolved_plan.trajectory = OrbitModel.build_trajectory(body, launch_state, resolved_burns)
	return resolved_plan


## Scales each pulse to the velocity change the rocket can really deliver.
## The player's two components give the direction; PlanSummary gives the size.
static func create_resolved_burns(plan: MissionPlan, summary: PlanSummary) -> Array[ResolvedBurn]:
	var resolved_burns: Array[ResolvedBurn] = []
	for pulse_index in plan.pulses.size():
		var pulse: Pulse = plan.pulses[pulse_index]
		var requested_delta_v: float = pulse.requested_delta_v_meters_per_second()
		var delivered_delta_v: float = 0.0
		if pulse_index < summary.delta_v_delivered_by_pulse.size():
			delivered_delta_v = summary.delta_v_delivered_by_pulse[pulse_index]

		var delivered_share: float = 0.0
		if requested_delta_v > 0.0:
			delivered_share = delivered_delta_v / requested_delta_v

		var burn := ResolvedBurn.new()
		burn.pulse_index = pulse_index
		burn.polar_angle_radians = pulse.polar_angle_radians
		burn.extra_revolutions = pulse.extra_revolutions
		burn.fires_immediately = pulse.fires_immediately
		burn.delta_v_along_velocity_meters_per_second = pulse.delta_v_along_velocity_meters_per_second * delivered_share
		burn.delta_v_outward_meters_per_second = pulse.delta_v_outward_meters_per_second * delivered_share
		resolved_burns.append(burn)
	return resolved_burns
