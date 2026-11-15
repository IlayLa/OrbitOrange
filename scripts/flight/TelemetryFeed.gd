extends RefCounted
## Samples installed instruments on the simulation clock and holds their last readings.

const CHANNELS: Array[String] = [
	TelemetryFrame.CHANNEL_ALTITUDE_METERS,
	TelemetryFrame.CHANNEL_FUEL_KILOGRAMS,
	TelemetryFrame.CHANNEL_ATTITUDE_RADIANS,
	TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS,
]
const RADAR_CHANNEL := "radar"
const CHANNELS_WITH_RADAR: Array[String] = [
	TelemetryFrame.CHANNEL_ALTITUDE_METERS,
	TelemetryFrame.CHANNEL_FUEL_KILOGRAMS,
	TelemetryFrame.CHANNEL_ATTITUDE_RADIANS,
	TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS,
	RADAR_CHANNEL,
]
const RADAR_RANGE_LOSS_PER_NOISE_ADDITION := 2.5

var _random: RandomNumberGenerator
var _parts_by_channel: Dictionary = {}
# The installed channels in CHANNELS_WITH_RADAR order, with what sampling needs
# per channel kept in parallel arrays: sampling runs thousands of times per
# second at high speed, where dictionary lookups add up.
var _sampled_channels: Array[String] = []
var _sampled_parts: Array[Dictionary] = []
var _sample_periods_seconds := PackedFloat64Array()
var _dropout_probabilities := PackedFloat64Array()
var _next_sample_times_seconds := PackedFloat64Array()
# Scratch arrays for _sample_due, sized once to the channel count.
var _is_working_by_index := PackedByteArray()
var _dropout_by_index := PackedFloat64Array()
var _held_readings: Dictionary = {}
var _held_contacts: Dictionary = {}
var _interference_noise := 0.0
var _interference_dropout := 0.0


func _init(vehicle_state: VehicleState, random: RandomNumberGenerator) -> void:
	_random = random
	for part_id in vehicle_state.design.payload_part_ids:
		var part: Dictionary = GameData.part(part_id)
		if part.get("category", "") != "telemetry":
			continue
		var stats: Dictionary = part.get("stats", {})
		var channel: String = stats.get("channel", "")
		if not CHANNELS_WITH_RADAR.has(channel):
			continue
		var current_part: Dictionary = _parts_by_channel.get(channel, {})
		if part.get("tier", 0) > current_part.get("tier", 0):
			_parts_by_channel[channel] = part
	for channel in CHANNELS_WITH_RADAR:
		if not _parts_by_channel.has(channel):
			continue
		var part: Dictionary = _parts_by_channel[channel]
		var stats: Dictionary = part["stats"]
		var updates_per_second: float = stats.get("updates_per_second", 0.0)
		_sampled_channels.append(channel)
		_sampled_parts.append(part)
		_sample_periods_seconds.append(1.0 / updates_per_second if updates_per_second > 0.0 else INF)
		_dropout_probabilities.append(float(stats.get("dropout_probability", 0.0)))
		_next_sample_times_seconds.append(0.0)


## Returns the earliest scheduled instrument update in seconds since launch.
func next_sample_time_seconds() -> float:
	var next_time_seconds := INF
	for sample_time_seconds in _next_sample_times_seconds:
		next_time_seconds = minf(next_time_seconds, sample_time_seconds)
	return next_time_seconds


## Returns the next scheduled sample of one channel, or INF when it has no
## instrument.
func next_sample_time_seconds_of(channel: String) -> float:
	var channel_index := _sampled_channels.find(channel)
	return _next_sample_times_seconds[channel_index] if channel_index >= 0 else INF


## Returns the noise fraction a channel's readings carry now, interference
## included: a reading lies within this fraction of the true value.
func noise_fraction_of(channel: String) -> float:
	var part: Dictionary = _parts_by_channel.get(channel, {})
	return float(part.get("stats", {}).get("noise_fraction", 0.0)) + _interference_noise


func set_interference(noise_fraction_addition: float, dropout_probability_addition: float) -> void:
	_interference_noise = noise_fraction_addition
	_interference_dropout = dropout_probability_addition


## Whether a channel's instrument can produce a reading now: installed, working
## and not dropping every sample. Changes only at flight boundaries.
func can_report(channel: String, vehicle_state: VehicleState) -> bool:
	var channel_index := _sampled_channels.find(channel)
	if channel_index < 0:
		return false
	var part := _sampled_parts[channel_index]
	return (vehicle_state.is_working_by_instrument.get(part["id"], false)
			and _dropout_probabilities[channel_index] + _interference_dropout < 1.0)


## The latest valid observation, if the selected instrument is still working.
func valid_reading(channel: String, vehicle_state: VehicleState) -> TelemetryReading:
	var held: TelemetryReading = _held_readings.get(channel)
	if held != null and held.is_sensor_working:
		var part: Dictionary = _parts_by_channel[channel]
		if vehicle_state.is_working_by_instrument.get(part["id"], false):
			return held
	return null


## Samples due channels at the current simulation time.
func sample(
		values_by_channel: Dictionary, craft_state: OrbitState, vehicle_state: VehicleState,
		threats: Array[Threat], gravitational_parameter: float, simulation_time_seconds: float) -> void:
	_sample_due(simulation_time_seconds, true,
			func(channel: String, _time_seconds: float) -> float: return values_by_channel[channel],
			func(_time_seconds: float) -> OrbitState: return craft_state,
			vehicle_state, threats, gravitational_parameter)


## Takes every sample scheduled before end_time_seconds, in time order, so the
## flight need not stop at each one. value_at is a Callable that takes a
## channel and a time in seconds and returns the channel's true value then;
## craft_state_at takes a time and returns the craft state then. A sample that
## a later one in the same call replaces only draws its dropout and noise, so
## the random sequence, and every reading left held, match sampling at each
## scheduled time. Radar samples with threats around are always taken in full,
## since they reveal threats. The instruments' health and the interference must
## not change before end_time_seconds.
func sample_before(
		end_time_seconds: float, value_at: Callable, craft_state_at: Callable,
		vehicle_state: VehicleState, threats: Array[Threat], gravitational_parameter: float) -> void:
	_sample_due(end_time_seconds, false, value_at, craft_state_at, vehicle_state, threats, gravitational_parameter)


func _sample_due(
		end_time_seconds: float, includes_end: bool, value_at: Callable, craft_state_at: Callable,
		vehicle_state: VehicleState, threats: Array[Threat], gravitational_parameter: float) -> void:
	var channel_count := _sampled_channels.size()
	# Health and interference only change at flight boundaries, never inside a call.
	_is_working_by_index.resize(channel_count)
	_dropout_by_index.resize(channel_count)
	for channel_index in channel_count:
		_is_working_by_index[channel_index] = 1 if vehicle_state.is_working_by_instrument.get(
				_sampled_parts[channel_index]["id"], false) else 0
		_dropout_by_index[channel_index] = clampf(_dropout_probabilities[channel_index] + _interference_dropout, 0.0, 1.0)
	# Samples are taken in time order, channels in CHANNELS_WITH_RADAR order at
	# equal times, as if the flight stopped at each: they share _random.
	while true:
		var time_seconds := INF
		for sample_time_seconds in _next_sample_times_seconds:
			time_seconds = minf(time_seconds, sample_time_seconds)
		if not (time_seconds < end_time_seconds or (includes_end and time_seconds == end_time_seconds)):
			return
		for channel_index in channel_count:
			if _next_sample_times_seconds[channel_index] != time_seconds:
				continue
			var next_time_seconds := time_seconds + _sample_periods_seconds[channel_index]
			_next_sample_times_seconds[channel_index] = next_time_seconds
			var has_signal: bool = _is_working_by_index[channel_index] == 1 and _random.randf() >= _dropout_by_index[channel_index]
			var channel := _sampled_channels[channel_index]
			if channel == RADAR_CHANNEL:
				_held_contacts.clear()
				if has_signal and not threats.is_empty():
					_sample_radar(_sampled_parts[channel_index]["stats"], craft_state_at.call(time_seconds),
							threats, gravitational_parameter)
			elif next_time_seconds < end_time_seconds or (includes_end and next_time_seconds == end_time_seconds):
				# A later sample in this call replaces this reading: draw its noise only.
				if has_signal:
					_random.randf_range(-1.0, 1.0)
			else:
				var part := _sampled_parts[channel_index]
				var reading := TelemetryReading.new()
				reading.is_sensor_installed = true
				reading.is_sensor_working = has_signal
				reading.sensor_tier = part["tier"]
				reading.sample_time_seconds = time_seconds
				if has_signal:
					var value: float = value_at.call(channel, time_seconds)
					if channel == TelemetryFrame.CHANNEL_ATTITUDE_RADIANS or channel == TelemetryFrame.CHANNEL_FLIGHT_PATH_ANGLE_RADIANS:
						reading.value = _noisy_value(value, part["stats"], PI / 2.0)
					else:
						reading.value = _noisy_value(value, part["stats"])
				_held_readings[channel] = reading


## Copies held instrument observations into a fresh frame.
func fill_frame(
		frame: TelemetryFrame, craft_state: OrbitState, vehicle_state: VehicleState,
		threats: Array[Threat], gravitational_parameter: float) -> void:
	for channel in CHANNELS:
		var reading := TelemetryReading.new()
		if _parts_by_channel.has(channel):
			var part: Dictionary = _parts_by_channel[channel]
			var held := valid_reading(channel, vehicle_state)
			reading.is_sensor_installed = true
			reading.sensor_tier = part["tier"]
			if held != null:
				reading.is_sensor_working = held.is_sensor_working
				reading.value = held.value
				reading.sample_time_seconds = held.sample_time_seconds
		frame.readings_by_channel[channel] = reading

	frame.is_radar_installed = _parts_by_channel.has(RADAR_CHANNEL)
	if not frame.is_radar_installed:
		return
	var radar: Dictionary = _parts_by_channel[RADAR_CHANNEL]
	if not vehicle_state.is_working_by_instrument.get(radar["id"], false):
		return
	var maximum_range_meters := _radar_range_meters(radar["stats"])
	for threat in threats:
		if not _held_contacts.has(threat.threat_id) or threat.state == null:
			continue
		var state: OrbitState = _threat_state_at(threat, craft_state.time_seconds, gravitational_parameter)
		if _distance_meters(craft_state, state) <= maximum_range_meters:
			frame.radar_contacts.append(_held_contacts[threat.threat_id].duplicate())


## Drops a cached contact when its threat is removed.
func forget_threat(threat_id: int) -> void:
	_held_contacts.erase(threat_id)


## Returns the true range, in metres, to the closest supplied threat.
static func nearest_threat_range_meters(
		craft_state: OrbitState, threats: Array[Threat], gravitational_parameter: float) -> float:
	var nearest_range_meters := INF
	for threat in threats:
		if threat.state != null:
			var state: OrbitState = _threat_state_at(threat, craft_state.time_seconds, gravitational_parameter)
			nearest_range_meters = minf(nearest_range_meters, _distance_meters(craft_state, state))
	return nearest_range_meters


func _sample_radar(
		stats: Dictionary, craft_state: OrbitState, threats: Array[Threat],
		gravitational_parameter: float) -> void:
	var maximum_range_meters := _radar_range_meters(stats)
	var resolution_level: int = clampi(int(stats.get("resolution_level", 0)), 0, 2)
	for threat in threats:
		if threat.state == null:
			continue
		var state: OrbitState = _threat_state_at(threat, craft_state.time_seconds, gravitational_parameter)
		var relative_x_meters: float = state.position_x_meters - craft_state.position_x_meters
		var relative_y_meters: float = state.position_y_meters - craft_state.position_y_meters
		var range_meters: float = sqrt(relative_x_meters * relative_x_meters + relative_y_meters * relative_y_meters)
		if range_meters > maximum_range_meters:
			continue
		var closing_speed_meters_per_second := 0.0
		if resolution_level == 2 and range_meters > 0.0:
			var relative_velocity_x_meters_per_second: float = (
					state.velocity_x_meters_per_second - craft_state.velocity_x_meters_per_second)
			var relative_velocity_y_meters_per_second: float = (
					state.velocity_y_meters_per_second - craft_state.velocity_y_meters_per_second)
			closing_speed_meters_per_second = -(
					relative_x_meters * relative_velocity_x_meters_per_second
					+ relative_y_meters * relative_velocity_y_meters_per_second) / range_meters
			closing_speed_meters_per_second = _noisy_value(closing_speed_meters_per_second, stats)
		_held_contacts[threat.threat_id] = {
			"bearing_radians": wrapf(_noisy_value(atan2(relative_y_meters, relative_x_meters), stats, PI), -PI, PI),
			"range_meters": maxf(0.0, _noisy_value(range_meters, stats)),
			"closing_speed_meters_per_second": closing_speed_meters_per_second,
			"resolution_level": resolution_level,
			"event_type_id": threat.event_type_id if resolution_level == 2 else "",
		}
		threat.is_revealed = true


func _radar_range_meters(stats: Dictionary) -> float:
	var range_retained := maxf(0.0, 1.0 - _interference_noise * RADAR_RANGE_LOSS_PER_NOISE_ADDITION)
	return float(stats.get("range_kilometers", 0.0)) * 1000.0 * range_retained


func _noisy_value(value: float, stats: Dictionary, angular_scale: float = 0.0) -> float:
	var noise_fraction: float = float(stats.get("noise_fraction", 0.0)) + _interference_noise
	var scale := angular_scale if angular_scale > 0.0 else value
	return value + scale * noise_fraction * _random.randf_range(-1.0, 1.0)


static func _threat_state_at(threat: Threat, time_seconds: float, gravitational_parameter: float) -> OrbitState:
	if time_seconds == threat.state.time_seconds:
		return threat.state
	return Kepler.propagate(gravitational_parameter, threat.state, time_seconds - threat.state.time_seconds)


static func _distance_meters(first: OrbitState, second: OrbitState) -> float:
	var difference_x_meters: float = first.position_x_meters - second.position_x_meters
	var difference_y_meters: float = first.position_y_meters - second.position_y_meters
	return sqrt(difference_x_meters * difference_x_meters + difference_y_meters * difference_y_meters)
