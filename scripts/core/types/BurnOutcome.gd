class_name BurnOutcome
extends RefCounted
## What actually happened when one stage fired. Returned by RocketModel.apply_burn.

## May be less than requested when the propellant ran out.
var delta_v_delivered_meters_per_second: float = 0.0
var propellant_used_kilograms: float = 0.0
## How long the engine burned, from its thrust and mass flow. Used for readouts only.
var burn_duration_seconds: float = 0.0
var mass_before_kilograms: float = 0.0
var mass_after_kilograms: float = 0.0
## Stages dropped by this burn: lower stages before it, and this stage if it emptied.
var jettisoned_stage_ids: Array[int] = []
## False when the stage could not fire at all (failed, already jettisoned, or empty).
var did_fire: bool = false
