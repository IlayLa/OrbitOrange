extends RefCounted
## Checks the two-body mathematics in Kepler.gd against known values and
## against its own invariants (energy, angular momentum, round trips). T01.

var gravitational_parameter: float = 0.0
var body_radius_meters: float = 0.0
var atmosphere_height_meters: float = 0.0


func run_tests(report: TestReport) -> void:
	var earth: Dictionary = GameData.body("earth")
	gravitational_parameter = earth["gravitational_parameter_cubic_meters_per_second_squared"]
	body_radius_meters = earth["radius_meters"]
	atmosphere_height_meters = earth["atmosphere_height_meters"]

	_check_circular_orbit(report)
	_check_hohmann_transfer(report)
	_check_propagation_returns_after_one_period(report)
	_check_negative_and_long_durations(report)
	_check_invariants_along_orbits(report)
	_check_element_round_trips(report)
	_check_escape_speed(report)
	_check_clockwise_convention(report)
	_check_launch_state(earth, report)
	_check_seconds_until_polar_angle(report)
	_check_seconds_until_impact(earth, report)
	_check_fraction_inside_band(report)


func _check_circular_orbit(report: TestReport) -> void:
	var orbit_radius: float = body_radius_meters + 400000.0
	var speed: float = Kepler.circular_speed_meters_per_second(gravitational_parameter, orbit_radius)
	report.check_close(speed, 7672.6, 0.1, "circular speed at 400 km")
	var elements: OrbitElements = Kepler.elements_from_state(
			gravitational_parameter, OrbitState.create(orbit_radius, 0.0, 0.0, speed))
	report.check_close(elements.period_seconds, 5545.0, 1.0, "period of a 400 km circular orbit")
	report.check(elements.is_circular, "a state at circular speed gives a circular orbit")


func _check_hohmann_transfer(report: TestReport) -> void:
	var inner_radius: float = body_radius_meters + 400000.0
	var outer_radius: float = body_radius_meters + 800000.0
	var inner_speed: float = Kepler.circular_speed_meters_per_second(gravitational_parameter, inner_radius)
	var first_pulse: float = inner_speed * (sqrt(2.0 * outer_radius / (inner_radius + outer_radius)) - 1.0)
	report.check_close(first_pulse, 109.3, 0.1, "first Hohmann pulse from 400 km to 800 km")

	var transfer_state: OrbitState = Kepler.apply_pulse(
			OrbitState.create(inner_radius, 0.0, 0.0, inner_speed), first_pulse, 0.0)
	var transfer_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, transfer_state)
	report.check_close(transfer_elements.apoapsis_radius_meters, outer_radius, 1.0e-3, "the transfer orbit's apoapsis is at 800 km")

	var seconds_to_apoapsis: float = Kepler.seconds_until_polar_angle(gravitational_parameter, transfer_state, PI, 0)
	report.check_close(seconds_to_apoapsis, 0.5 * transfer_elements.period_seconds, 1.0e-6, "the apoapsis is half a period away")
	var apoapsis_state: OrbitState = Kepler.propagate(gravitational_parameter, transfer_state, seconds_to_apoapsis)
	report.check_close(apoapsis_state.radius_meters(), outer_radius, 1.0e-3, "propagating to the apoapsis reaches 800 km")
	var second_pulse: float = (
			Kepler.circular_speed_meters_per_second(gravitational_parameter, outer_radius)
			- apoapsis_state.speed_meters_per_second())
	report.check_close(second_pulse, 107.7, 0.1, "second Hohmann pulse from 400 km to 800 km")


func _check_propagation_returns_after_one_period(report: TestReport) -> void:
	var start_state: OrbitState = _ellipse_at_periapsis(0.2, 0.7, false)
	var period_seconds: float = Kepler.elements_from_state(gravitational_parameter, start_state).period_seconds
	var step_count := 7
	var current_state: OrbitState = start_state
	for _step_index in step_count:
		current_state = Kepler.propagate(gravitational_parameter, current_state, period_seconds / step_count)
	_check_same_state(report, current_state, start_state, 1.0e-2, 1.0e-5, "seven steps of a seventh of a period return to the start")
	report.check_close(current_state.time_seconds, start_state.time_seconds + period_seconds, 1.0e-6, "the time advances by one period")


func _check_negative_and_long_durations(report: TestReport) -> void:
	var ellipse_state: OrbitState = _ellipse_at_periapsis(0.3, 1.1, false)
	var forward_state: OrbitState = Kepler.propagate(gravitational_parameter, ellipse_state, 1234.5)
	var back_state: OrbitState = Kepler.propagate(gravitational_parameter, forward_state, -1234.5)
	_check_same_state(report, back_state, ellipse_state, 1.0e-3, 1.0e-6, "forward then backward on an ellipse returns to the start")

	var period_seconds: float = Kepler.elements_from_state(gravitational_parameter, ellipse_state).period_seconds
	var after_many_periods: OrbitState = Kepler.propagate(gravitational_parameter, ellipse_state, 100.0 * period_seconds + 1000.0)
	var after_short_time: OrbitState = Kepler.propagate(gravitational_parameter, ellipse_state, 1000.0)
	_check_same_state(report, after_many_periods, after_short_time, 1.0e-2, 1.0e-5, "100 periods plus a time equals that time alone")

	var hyperbola_state: OrbitState = _ellipse_at_periapsis(1.5, 0.0, false)
	var hyperbola_forward: OrbitState = Kepler.propagate(gravitational_parameter, hyperbola_state, 5000.0)
	var hyperbola_back: OrbitState = Kepler.propagate(gravitational_parameter, hyperbola_forward, -5000.0)
	_check_same_state(report, hyperbola_back, hyperbola_state, 1.0e-3, 1.0e-6, "forward then backward on a hyperbola returns to the start")


func _check_invariants_along_orbits(report: TestReport) -> void:
	var cases: Dictionary = {
		"ellipse": _ellipse_at_periapsis(0.4, 0.3, false),
		"clockwise ellipse": _ellipse_at_periapsis(0.4, 2.0, true),
		"hyperbola": _ellipse_at_periapsis(1.8, -1.0, false),
	}
	for case_name: String in cases:
		var start_state: OrbitState = cases[case_name]
		var start_energy: float = _specific_energy(start_state)
		var start_angular_momentum: float = Kepler.signed_angular_momentum(start_state)
		var largest_energy_error: float = 0.0
		var largest_angular_momentum_error: float = 0.0
		for sample_index in 10:
			var sample_state: OrbitState = Kepler.propagate(gravitational_parameter, start_state, 900.0 * (sample_index + 1))
			largest_energy_error = maxf(largest_energy_error, absf(_specific_energy(sample_state) - start_energy))
			largest_angular_momentum_error = maxf(
					largest_angular_momentum_error,
					absf(Kepler.signed_angular_momentum(sample_state) - start_angular_momentum))
		report.check(
				largest_energy_error <= 1.0e-9 * absf(start_energy),
				"specific energy stays constant along the %s (largest error %s)" % [case_name, largest_energy_error])
		report.check(
				largest_angular_momentum_error <= 1.0e-9 * absf(start_angular_momentum),
				"angular momentum stays constant along the %s (largest error %s)" % [case_name, largest_angular_momentum_error])


func _check_element_round_trips(report: TestReport) -> void:
	var circle_radius: float = body_radius_meters + 500000.0
	var circle_speed: float = Kepler.circular_speed_meters_per_second(gravitational_parameter, circle_radius)
	var circle_angle: float = 1.0
	var cases: Dictionary = {
		"ellipse": Kepler.propagate(gravitational_parameter, _ellipse_at_periapsis(0.25, 0.8, false), 1500.0),
		"circle": OrbitState.create(
				circle_radius * cos(circle_angle), circle_radius * sin(circle_angle),
				-circle_speed * sin(circle_angle), circle_speed * cos(circle_angle)),
		"clockwise ellipse": Kepler.propagate(gravitational_parameter, _ellipse_at_periapsis(0.25, 0.8, true), 1500.0),
		"clockwise circle": OrbitState.create(
				circle_radius * cos(circle_angle), circle_radius * sin(circle_angle),
				circle_speed * sin(circle_angle), -circle_speed * cos(circle_angle)),
		"open orbit": Kepler.propagate(gravitational_parameter, _ellipse_at_periapsis(1.3, 2.5, false), 2000.0),
	}
	for case_name: String in cases:
		var original_state: OrbitState = cases[case_name]
		var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, original_state)
		var rebuilt_state: OrbitState = Kepler.state_from_elements(gravitational_parameter, elements, original_state.time_seconds)
		_check_same_state(
				report, rebuilt_state, original_state,
				1.0e-9 * original_state.radius_meters(), 1.0e-9 * original_state.speed_meters_per_second(),
				"elements_from_state then state_from_elements returns the %s" % case_name)
	report.check(
			Kepler.elements_from_state(gravitational_parameter, cases["clockwise ellipse"]).is_clockwise,
			"a clockwise state sets is_clockwise")
	report.check(
			Kepler.elements_from_state(gravitational_parameter, cases["open orbit"]).semi_major_axis_meters < 0.0,
			"an open orbit has a negative semi-major axis")


func _check_escape_speed(report: TestReport) -> void:
	var start_radius: float = body_radius_meters + 300000.0
	var escape_speed: float = sqrt(2.0 * gravitational_parameter / start_radius)
	var fast_elements: OrbitElements = Kepler.elements_from_state(
			gravitational_parameter, OrbitState.create(start_radius, 0.0, 0.0, 1.01 * escape_speed))
	report.check(fast_elements.is_open, "a state above escape speed gives an open orbit")
	report.check(is_inf(fast_elements.period_seconds) and is_inf(fast_elements.apoapsis_radius_meters),
			"an open orbit has infinite period and apoapsis")

	var parabolic_state := OrbitState.create(start_radius, 0.0, 0.0, escape_speed)
	var parabolic_later: OrbitState = Kepler.propagate(gravitational_parameter, parabolic_state, 3000.0)
	var parabolic_back: OrbitState = Kepler.propagate(gravitational_parameter, parabolic_later, -3000.0)
	report.check(
			is_finite(parabolic_later.position_x_meters) and parabolic_later.radius_meters() > start_radius,
			"a state at exactly escape speed propagates outward without NaN")
	_check_same_state(report, parabolic_back, parabolic_state, 1.0e-3, 1.0e-6, "forward then backward at escape speed returns to the start")
	report.check(
			not is_inf(Kepler.seconds_until_polar_angle(gravitational_parameter, parabolic_state, 1.0, 0)),
			"at escape speed a direction ahead of the craft is reached")


func _check_clockwise_convention(report: TestReport) -> void:
	# Periapsis drawn at 30 degrees, motion clockwise: GMAT's inverse with
	# inclination 180 degrees gives argument of periapsis 330 degrees.
	var periapsis_radius: float = body_radius_meters + 500000.0
	var periapsis_speed: float = sqrt(gravitational_parameter * 1.2 / periapsis_radius)
	var periapsis_angle: float = deg_to_rad(30.0)
	var clockwise_state := OrbitState.create(
			periapsis_radius * cos(periapsis_angle), periapsis_radius * sin(periapsis_angle),
			periapsis_speed * sin(periapsis_angle), -periapsis_speed * cos(periapsis_angle))
	var elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, clockwise_state)
	report.check_close(rad_to_deg(elements.argument_of_periapsis_radians), 330.0, 1.0e-7,
			"a clockwise orbit's argument of periapsis is measured clockwise")
	report.check_close(_angle_difference(elements.true_anomaly_radians, 0.0), 0.0, 1.0e-9,
			"a clockwise state at periapsis has true anomaly 0")

	elements.true_anomaly_radians = deg_to_rad(45.0)
	var later_state: OrbitState = Kepler.state_from_elements(gravitational_parameter, elements, 0.0)
	report.check_close(rad_to_deg(later_state.polar_angle_radians()), -15.0, 1.0e-7,
			"45 degrees past a periapsis at 30 degrees, clockwise, is at -15 degrees")

	var moved_state: OrbitState = Kepler.propagate(gravitational_parameter, clockwise_state, 700.0)
	var moved_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, moved_state)
	report.check_close(
			_angle_difference(
					moved_state.polar_angle_radians(),
					-(moved_elements.argument_of_periapsis_radians + moved_elements.true_anomaly_radians)),
			0.0, 1.0e-9, "for a clockwise orbit the polar angle is -(argument of periapsis + true anomaly)")


func _check_launch_state(earth: Dictionary, report: TestReport) -> void:
	var launch_angle: float = deg_to_rad(20.0)
	var state: OrbitState = Kepler.launch_state(earth, deg_to_rad(90.0), 7000.0, launch_angle)
	report.check_close(state.radius_meters(), body_radius_meters, 1.0e-6, "the launch state is on the surface")
	report.check_close(state.speed_meters_per_second(), 7000.0, 1.0e-9, "the launch state moves at burnout speed")
	report.check_close(Kepler.flight_path_angle_radians(state), launch_angle, 1.0e-12, "the launch state climbs at the launch angle")
	report.check(Kepler.signed_angular_momentum(state) > 0.0, "the launch state moves counter-clockwise")
	report.check_close(state.time_seconds, 0.0, 0.0, "the launch state is at time 0")


func _check_seconds_until_polar_angle(report: TestReport) -> void:
	for is_clockwise: bool in [false, true]:
		var direction_name: String = "clockwise" if is_clockwise else "counter-clockwise"
		var start_state: OrbitState = _ellipse_at_periapsis(0.3, 0.4, is_clockwise)
		var target_angle: float = 2.0
		var seconds_to_target: float = Kepler.seconds_until_polar_angle(gravitational_parameter, start_state, target_angle, 0)
		var target_state: OrbitState = Kepler.propagate(gravitational_parameter, start_state, seconds_to_target)
		report.check_close(_angle_difference(target_state.polar_angle_radians(), target_angle), 0.0, 1.0e-8,
				"propagating by seconds_until_polar_angle reaches the direction (%s)" % direction_name)
		var period_seconds: float = Kepler.elements_from_state(gravitational_parameter, start_state).period_seconds
		report.check_close(
				Kepler.seconds_until_polar_angle(gravitational_parameter, start_state, target_angle, 1),
				seconds_to_target + period_seconds, 1.0e-6,
				"one extra revolution adds one period (%s)" % direction_name)
		report.check_close(
				Kepler.seconds_until_polar_angle(gravitational_parameter, start_state, start_state.polar_angle_radians(), 0),
				0.0, 0.0, "the current direction is reached now (%s)" % direction_name)

	var hyperbola_state: OrbitState = _ellipse_at_periapsis(1.5, 0.0, false)
	report.check(is_inf(Kepler.seconds_until_polar_angle(gravitational_parameter, hyperbola_state, -0.5, 0)),
			"an open orbit never reaches a direction behind the craft")
	report.check(is_inf(Kepler.seconds_until_polar_angle(gravitational_parameter, hyperbola_state, 0.5, 1)),
			"an open orbit cannot wait extra revolutions")
	var seconds_ahead: float = Kepler.seconds_until_polar_angle(gravitational_parameter, hyperbola_state, 1.5, 0)
	var ahead_state: OrbitState = Kepler.propagate(gravitational_parameter, hyperbola_state, seconds_ahead)
	report.check_close(_angle_difference(ahead_state.polar_angle_radians(), 1.5), 0.0, 1.0e-8,
			"an open orbit reaches a direction ahead of the craft")
	report.check(is_inf(Kepler.seconds_until_polar_angle(gravitational_parameter, hyperbola_state, 3.0, 0)),
			"an open orbit never reaches a direction beyond its asymptote")


func _check_seconds_until_impact(earth: Dictionary, report: TestReport) -> void:
	var impact_radius: float = body_radius_meters + atmosphere_height_meters
	var horizontal_launch: OrbitState = Kepler.launch_state(earth, deg_to_rad(90.0), 7000.0, 0.0)
	report.check_close(Kepler.seconds_until_impact(gravitational_parameter, horizontal_launch, impact_radius), 0.0, 0.0,
			"a horizontal launch below circular speed impacts at once")

	var climbing_launch: OrbitState = Kepler.launch_state(earth, deg_to_rad(90.0), 7000.0, deg_to_rad(30.0))
	var seconds_to_impact: float = Kepler.seconds_until_impact(gravitational_parameter, climbing_launch, impact_radius)
	report.check(seconds_to_impact > 0.0 and not is_inf(seconds_to_impact), "a climbing launch impacts after some time")
	var impact_state: OrbitState = Kepler.propagate(gravitational_parameter, climbing_launch, seconds_to_impact)
	report.check_close(impact_state.radius_meters(), impact_radius, 1.0e-2, "the impact happens at the top of the atmosphere")
	var radial_velocity: float = (
			impact_state.position_x_meters * impact_state.velocity_x_meters_per_second
			+ impact_state.position_y_meters * impact_state.velocity_y_meters_per_second)
	report.check(radial_velocity < 0.0, "the craft is moving inward at the impact")

	var safe_orbit: OrbitState = _ellipse_at_periapsis(0.1, 0.0, false)
	report.check(is_inf(Kepler.seconds_until_impact(gravitational_parameter, safe_orbit, impact_radius)),
			"an orbit with periapsis above the atmosphere never impacts")


func _check_fraction_inside_band(report: TestReport) -> void:
	var circle_radius: float = body_radius_meters + 400000.0
	var circle_elements: OrbitElements = Kepler.elements_from_state(
			gravitational_parameter,
			OrbitState.create(circle_radius, 0.0, 0.0, Kepler.circular_speed_meters_per_second(gravitational_parameter, circle_radius)))
	report.check_close(Kepler.fraction_of_period_inside_band(
			circle_elements, body_radius_meters + 300000.0, body_radius_meters + 500000.0), 1.0, 0.0,
			"a circular orbit inside the band spends all its time there")
	report.check_close(Kepler.fraction_of_period_inside_band(
			circle_elements, body_radius_meters + 500000.0, body_radius_meters + 600000.0), 0.0, 0.0,
			"a circular orbit outside the band spends no time there")

	var ellipse_state: OrbitState = _ellipse_at_periapsis(0.15, 0.0, false)
	var ellipse_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, ellipse_state)
	report.check_close(Kepler.fraction_of_period_inside_band(
			ellipse_elements, body_radius_meters, ellipse_elements.apoapsis_radius_meters + 1000.0), 1.0, 1.0e-12,
			"a band containing the whole ellipse covers the whole period")

	var inner_radius: float = ellipse_elements.periapsis_radius_meters + 300000.0
	var outer_radius: float = ellipse_elements.periapsis_radius_meters + 1200000.0
	var sample_count := 10000
	var inside_count := 0
	for sample_index in sample_count:
		var sample_state: OrbitState = Kepler.propagate(
				gravitational_parameter, ellipse_state, ellipse_elements.period_seconds * (sample_index + 0.5) / sample_count)
		var sample_radius: float = sample_state.radius_meters()
		if sample_radius >= inner_radius and sample_radius <= outer_radius:
			inside_count += 1
	report.check_close(
			Kepler.fraction_of_period_inside_band(ellipse_elements, inner_radius, outer_radius),
			float(inside_count) / sample_count, 1.0e-3,
			"the band fraction matches counting propagated samples")

	var open_elements: OrbitElements = Kepler.elements_from_state(gravitational_parameter, _ellipse_at_periapsis(1.2, 0.0, false))
	report.check_close(Kepler.fraction_of_period_inside_band(open_elements, 0.0, INF), 0.0, 0.0, "an open orbit has no coverage")


## A state at periapsis, 500 km up, with the given eccentricity, periapsis
## direction and sense of motion.
func _ellipse_at_periapsis(eccentricity: float, periapsis_angle_radians: float, is_clockwise: bool) -> OrbitState:
	var periapsis_radius: float = body_radius_meters + 500000.0
	var periapsis_speed: float = sqrt(gravitational_parameter * (1.0 + eccentricity) / periapsis_radius)
	var motion_sign: float = -1.0 if is_clockwise else 1.0
	return OrbitState.create(
			periapsis_radius * cos(periapsis_angle_radians),
			periapsis_radius * sin(periapsis_angle_radians),
			-motion_sign * periapsis_speed * sin(periapsis_angle_radians),
			motion_sign * periapsis_speed * cos(periapsis_angle_radians))


func _specific_energy(state: OrbitState) -> float:
	var speed: float = state.speed_meters_per_second()
	return 0.5 * speed * speed - gravitational_parameter / state.radius_meters()


## Smallest signed difference between two angles, in -PI to PI.
func _angle_difference(first_angle_radians: float, second_angle_radians: float) -> float:
	var difference: float = fposmod(first_angle_radians - second_angle_radians, TAU)
	return difference - TAU if difference > PI else difference


func _check_same_state(
		report: TestReport,
		actual_state: OrbitState,
		expected_state: OrbitState,
		position_tolerance_meters: float,
		velocity_tolerance_meters_per_second: float,
		description: String) -> void:
	var position_error: float = sqrt(
			pow(actual_state.position_x_meters - expected_state.position_x_meters, 2.0)
			+ pow(actual_state.position_y_meters - expected_state.position_y_meters, 2.0))
	var velocity_error: float = sqrt(
			pow(actual_state.velocity_x_meters_per_second - expected_state.velocity_x_meters_per_second, 2.0)
			+ pow(actual_state.velocity_y_meters_per_second - expected_state.velocity_y_meters_per_second, 2.0))
	report.check(
			position_error <= position_tolerance_meters and velocity_error <= velocity_tolerance_meters_per_second,
			"%s (position error %s m, velocity error %s m/s)" % [description, position_error, velocity_error])
