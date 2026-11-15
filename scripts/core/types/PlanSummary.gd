class_name PlanSummary
extends RefCounted
## The result of running the whole mass chain for a design and a plan.
## Returned by RocketModel.summarize_plan. The stat chips, the engine list and
## the Launch button all read from this.

var cost_million_usd: float = 0.0
## Mass at lift-off: every part plus all propellant.
var wet_mass_kilograms: float = 0.0
## Mass with all propellant removed.
var dry_mass_kilograms: float = 0.0
## Velocity change if every stage fired in order with nothing else planned.
var total_delta_v_meters_per_second: float = 0.0
## Speed at the end of the launch burn, after subtracting gravity and drag losses.
var burnout_speed_meters_per_second: float = 0.0
## One entry per pulse in MissionPlan.pulses, in the same order.
var delta_v_delivered_by_pulse: Array[float] = []
## One entry per pulse. False when the stage could not deliver what was asked.
var is_pulse_affordable: Array[bool] = []
## Stage id -> velocity change still available after the whole plan has run.
var delta_v_remaining_by_stage: Dictionary = {}
## Sum of delta_v_remaining_by_stage: the safety margin for emergencies.
var reserve_delta_v_meters_per_second: float = 0.0
## Human-readable problems, for example "Stage 2 has no tank". Advice that
## does not stop a launch starts with RocketModel.WARNING_PREFIX.
var warnings: Array[String] = []
## The sentences of warnings that stop a launch. Empty means Launch is allowed.
var blocking_problems: Array[String] = []

## Automatic ascent and per-player-pulse physical allocations. Null for legacy plans.
var ascent: AscentResult
var pulse_allocations: Array[BurnAllocation] = []
var mass_after_ascent_kilograms: float = 0.0
var mass_after_pulse_kilograms: Array[float] = []
