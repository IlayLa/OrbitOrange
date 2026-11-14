# T03 · Flight simulation

**Lane C · Wave 1 · Branch `task/T03-flight-simulation` · Needs: the skeleton on `main`. Works on the stubs of T01 and T02.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Fly the planned mission: advance time at a chosen speed, fire the planned pulses, track science data, and produce the telemetry the control room sees, degraded by the quality of the installed sensors.

## Files you own
- `autoload/FlightSimulation.gd`
- `scripts/flight/**` (new; for example `TelemetryFeed.gd`, `DataLink.gd`, `ScienceTracker.gd`)
- `tests/test_flight_simulation.gd` (new)
- `docs/ai_usage/T03.md`, `docs/references/T03.md`, `tasks/notes/T03.md` (new)

## What you provide
The fields, functions and signals of `FlightSimulation` listed in `CONTRACTS.md`, section 5, and correct `TelemetryFrame` and `FlightResult` objects.

## What you consume
| From | What | Until the real one is merged |
|---|---|---|
| T01 | `OrbitModel.build_trajectory_from_state`, `OrbitModel.state_at_time`, `Kepler.*` | every orbit is a 400 km circle and burns are ignored |
| T02 | `RocketModel.create_vehicle_state`, `apply_burn`, `total_mass_kilograms`, `available_delta_v_meters_per_second` | burns deliver exactly what is asked and change nothing |
| Integrator | `PlanResolver.resolve`, `GameData` | real |

Write your code against the real behaviour described in those files' comments. Re-run your tests when T01 and T02 are merged.

## Requirements
Design reference: `context/plan_draft.md`, sections "Execution instruments", "Time controls", "Science data and the data link" and the "Ascent readout" bullet. Rules: `CONTRACTS.md`, "Flight time" and "Telemetry channels".

1. **Time.** Fixed steps of `SIMULATION_STEP_SECONDS`; `simulation_step` once per step; the time scales in `ALLOWED_TIME_SCALES`. Drop to 1× shortly before each planned pulse.
2. **Ascent.** Before the first orbit segment, play the launch burn as a readout: acceleration = thrust ÷ current mass, with the mass falling at thrust ÷ (specific impulse × standard gravity). This feeds the acceleration channel only; it does not change the trajectory.
3. **Planned pulses.** When the craft reaches a pulse, call `RocketModel.apply_burn` on the live `VehicleState` and emit `pulse_fired`.
4. **`apply_emergency_pulse`.** Fire the pulse now, rebuild the trajectory from the current state with the remaining planned pulses (`OrbitModel.build_trajectory_from_state`), and return the outcome.
5. **Ending.** End the flight with the right `FlightResult.EndReason`: mission duration reached, launch failure (the planned trajectory never reaches orbit), crash, escape (once the craft is 20 body radii away), or `end_flight` called by others.
6. **Telemetry.** One `TelemetryFrame` per drawn frame. For each channel, find the installed telemetry part and apply its `noise_fraction`, `updates_per_second` (hold the last value between updates) and `dropout_probability`. No part → `is_sensor_installed` false. A part marked not working in `VehicleState.is_working_by_instrument` → `is_sensor_working` false.
7. **Radar.** Turn each `Threat` within the radar's `range_kilometers` into a radar contact with the detail allowed by `resolution_level`, and set `Threat.is_revealed`.
8. **Alarms.** Fill `active_alarms` with `LOW_FUEL`, `OVER_TEMPERATURE` and `HAZARD_NEAR` when they apply. Temperature may be a simple model (rises during burns, falls otherwise); say so in your notes.
9. **Science.** While the science instrument works and the craft is inside the chosen science zone, generate data at the instrument's `data_rate_megabits_per_second`. Deliver it through one function with two implementations: version 1 delivers everything at once (use this); version 2 (ground-station contact, transmitter rate, storage) is written only if time allows.
10. **`FlightResult`.** Fill every field. `science_coverage_fraction` comes from `Kepler.fraction_of_period_inside_band` on the final orbit.
11. **Repeatable.** All randomness comes from one `RandomNumberGenerator` seeded with the `random_seed` argument.

## Out of scope
Creating threats and rolling for events (T07). Drawing panels (T08). Scoring (T04).

## How to check your work
In `tests/test_flight_simulation.gd`, drive the simulation by calling its step function directly rather than waiting for frames (add a public `advance_simulation(seconds)` for this and mention it in your notes).

| Check | Expected |
|---|---|
| Same seed twice | identical telemetry values |
| A design without an altimeter | altitude reading has `is_sensor_installed` false |
| Advancing past the mission duration | `flight_ended` with `MISSION_COMPLETED`, exactly once |
| Time scale 1000× versus 1× over the same simulated time | same number of `simulation_step` signals |
| Craft inside the science zone for 100 s | data generated ≈ 100 × the instrument's rate |
| A threat inside radar range | appears in `radar_contacts`; outside range it does not |

## Definition of done
- No `STUB(T03)` remains.
- `tools/check_project.sh` ends with "All checks passed."
- The three hand-back files exist.
