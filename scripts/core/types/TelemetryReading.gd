class_name TelemetryReading
extends RefCounted
## One instrument value as the control room sees it, already degraded by the
## quality of the installed sensor.

## False when no sensor for this channel is installed: the panel shows "NO SENSOR".
var is_sensor_installed: bool = false
## False when the sensor is installed but has failed: the panel shows "NO SIGNAL".
var is_sensor_working: bool = false
## The measured value, with sensor noise. The unit depends on the channel;
## see TelemetryFrame for the list.
var value: float = 0.0
## Time at which this observation was made, in simulated seconds since launch.
var sample_time_seconds: float = -INF
## Tier of the installed sensor, 1 (basic) to 3 (advanced). 0 when none is installed.
var sensor_tier: int = 0
