# OrbitOrange contracts

This file fixes everything two tasks must agree on: names, units, who owns which file, what each module offers, and the data formats. Read it before your task file.

**The code is the exact contract.** Every public function already exists in the skeleton with its final name, parameters and return type, and a comment saying what it must do. This file explains how the pieces fit; for an exact signature, open the file named here.

## 1. Naming rule
It applies to all code, JSON keys and documents.

- **Full words, no abbreviations.** `delta_v`, `specific_impulse`, `eccentricity`, `vehicle_state`, `stage_id`. Never `dv`, `isp`, `e`, `vs`, `uid`, `idx`, `tmp`.
- **Units are written in the name** of every number that has one: `_meters`, `_kilometers`, `_meters_per_second`, `_kilograms`, `_seconds`, `_radians`, `_degrees`, `_kilonewtons`, `_million_usd`, `_megabits`, `_pixels`.
- **Booleans read as statements:** `is_open`, `has_failed`, `did_fire`.
- **No single-letter variables**, including loop counters: `stage_index`, `pixel_x`.
- **One exception:** the parameter `gravitational_parameter` is always in m³/s². Its JSON key does spell the unit out.
- **Code uses SI units** (metres, kilograms, seconds, radians). JSON may use kilometres, kilonewtons, degrees and million USD because people edit it by hand; the key says which.
- Every public function has a `##` comment saying what it returns and in which unit.

## 2. Modules and file ownership
One owner per file. You may create and edit only the files your task file lists. "Integrator" means the human who merges the branches; ask for changes to those files in `tasks/notes/T0N.md`.

| Module | Files | Owner |
|---|---|---|
| Project settings | `project.godot` | Integrator |
| Shared types | `scripts/core/types/*.gd` | Integrator |
| Plan glue, layout, test helper, worked example, number texts | `scripts/core/PlanResolver.gd`, `ScreenLayout.gd`, `TestReport.gd`, `ExampleFlight.gd`, `NumberFormat.gd` | Integrator |
| Shared UI pieces: pixel glyphs, warning lamps, lamp bar, Data Sources codex | `scripts/ui/**` | Integrator (added by the text-walls redesign, see `tasks/notes/text_walls.md`) |
| Catalogue loader | `autoload/GameData.gd` | Integrator |
| Game state | `autoload/GameState.gd` | Integrator |
| Menu and console shell | `scripts/screens/*.gd`, `scenes/MainMenu.tscn`, `scenes/Console.tscn` | Integrator |
| Test runner, checks | `tests/TestRunner.*`, `tests/test_skeleton.gd`, `tools/check_project.*` | Integrator |
| Orbit mathematics | `scripts/orbit/Kepler.gd`, `scripts/orbit/OrbitModel.gd` | T01 |
| Rocket numbers | `scripts/rocket/RocketModel.gd`, `data/parts.json` | T02 |
| Flight | `autoload/FlightSimulation.gd`, `scripts/flight/**` | T03 |
| Missions and score | `data/missions.json`, `data/bodies.json`, `scripts/mission/**`, `scenes/MissionSelect.tscn`, `scenes/FinalScreen.tscn` | T04 |
| Orbit display and planning | `scripts/orbit/OrbitView.gd`, `scripts/orbit/OrbitPlanning.gd`, `scripts/orbit/planning/**`, `scenes/planning/OrbitPlanning.tscn` | T05 |
| Rocket design and planning overview | `scripts/design/**`, `scenes/PlanningConsole.tscn`, `scenes/planning/RocketDesign.tscn` | T06 |
| Events | `autoload/EventDirector.gd`, `scripts/events/**`, `scenes/events/**`, `data/event_types.json`; in wave 2 also the `hazard_zones` and `hazard_rates` keys of `data/missions.json` | T07 |
| Execution console | `scripts/execution/**`, `scenes/ExecutionConsole.tscn`, `tools/generate_placeholders.gd` | T08 |

Every task also owns its own `tests/test_<module>.gd` files, `scenes/development/T0N_*.tscn` demo scenes, and its three hand-back files (section 9).

## 3. Rules between modules
```
            GameData (catalogue) ── read by everyone
                    │
 MissionSelect(T04) ─► GameState ◄─ RocketDesign(T06)   OrbitPlanning(T05)
                          │  change design/plan, then notify_*()
                          ▼
                    PlanResolver
                     │                 │
          RocketModel(T02)        OrbitModel + Kepler(T01)
                          │ launch_requested
                          ▼
              FlightSimulation(T03) ──telemetry_updated──► ExecutionConsole(T08)
                          │  ▲
                          ▼  │
                     EventDirector(T07) ── shows threats with OrbitView(T05)
                          │ flight_ended
                          ▼
                     Scoring(T04) ──► FinalScreen(T04)
```
- **Logic is static classes** (`Kepler`, `OrbitModel`, `RocketModel`, `Scoring`). They use no scene tree and no game state. They may read the catalogue through `GameData`.
- **Screens never call each other.** A planning screen changes `GameState.design` or `GameState.plan`, calls `GameState.notify_design_changed()` or `notify_plan_changed()`, and every screen redraws on `GameState.derived_changed` from `GameState.summary` and `GameState.trajectory`.
- **Only `FlightSimulation` knows the true state of the craft in flight.** The execution console reads `TelemetryFrame` objects and nothing else.
- **`Kepler` knows nothing about rockets; `RocketModel` knows nothing about orbits.** They meet only in `PlanResolver`.
- **Nobody opens a data file** except `GameData`.

## 4. Shared types
All in `scripts/core/types/`. Open the file for the fields and their meaning.

| Type | What it is | Created by |
|---|---|---|
| `OrbitState` | position, velocity and time: the truth about an orbit | `Kepler` |
| `OrbitElements` | shape and orientation, computed from a state | `Kepler` |
| `Stage`, `RocketDesign` | what the player built | T06 screen |
| `Pulse`, `MissionPlan` | what the player planned | T05 screen |
| `VehicleState` | the rocket right now: propellant left, dropped stages, broken parts | `RocketModel` |
| `BurnOutcome` | what one engine firing really did | `RocketModel` |
| `PlanSummary` | cost, masses and delta-v per pulse and per stage; `warnings` and `blocking_problems` | `RocketModel` |
| `ResolvedBurn`, `ResolvedPlan` | a pulse after mass bookkeeping; summary + trajectory | `PlanResolver` |
| `TrajectorySegment`, `Trajectory` | the predicted flight path | `OrbitModel` |
| `Threat` | another object that may hit the craft | `EventDirector` |
| `TelemetryReading`, `TelemetryFrame` | what the instruments show | `FlightSimulation` |
| `FlightResult` | how the flight ended | `FlightSimulation` |
| `ScoreLine`, `ScoreReport` | the score with explanations | `Scoring` |

## 5. Public functions
Exact signatures and comments are in the file. A body marked `STUB(T0N)` is a placeholder that task T0N must replace; its comment says how the stub behaves meanwhile.

| File | Functions and signals |
|---|---|
| `scripts/orbit/Kepler.gd` | `circular_speed_meters_per_second`, `orbital_period_seconds`, `altitude_meters`, `flight_path_angle_radians`, `signed_angular_momentum`, `elements_from_state`, `state_from_elements`, `propagate`, `apply_pulse`, `launch_state`, `seconds_until_polar_angle`, `seconds_until_impact`, `seconds_until_escape`, `fraction_of_period_inside_band` |
| `scripts/orbit/OrbitModel.gd` | `build_trajectory`, `build_trajectory_from_state`, `state_at_time`, `sample_segment_points`, `sample_full_orbit_points`, `impact_radius_meters`, `escape_radius_meters` |
| `scripts/rocket/RocketModel.gd` | `delta_v_from_rocket_equation`, `propellant_needed_for_delta_v`, `total_cost_million_usd`, `all_part_ids`, `full_propellant_kilograms`, `create_vehicle_state`, `total_mass_kilograms`, `available_delta_v_meters_per_second`, `apply_burn`, `summarize_plan`, `validate_design` |
| `scripts/core/PlanResolver.gd` | `resolve(design, plan, mission) -> ResolvedPlan` |
| `autoload/GameData.gd` | `part`, `parts_in_category`, `all_missions`, `mission`, `body`, `all_event_types`, `event_type`, `register_part` |
| `autoload/GameState.gd` | fields `mission`, `science_mission_id`, `side_quest_ids`, `budget_million_usd`, `design`, `plan`, `summary`, `trajectory`, `has_launched`, `flight_result`, `score`, `random_seed`; functions `start_new_game`, `select_mission`, `science_mission`, `accepted_side_quests`, `notify_design_changed`, `notify_plan_changed`, `request_launch`, `finish_flight`, `go_to_scene`; signals `mission_changed`, `derived_changed`, `launch_requested`, `flight_finished` |
| `autoload/FlightSimulation.gd` | fields `is_flying`, `time_scale`, `simulation_time_seconds`, `craft_state`, `vehicle_state`, `trajectory`, `threats`, `event_log`; functions `start_flight`, `set_time_scale`, `pause`, `advance_simulation`, `apply_emergency_pulse`, `add_threat`, `remove_threat`, `log_event`, `raise_alert`, `end_flight`; signals `simulation_step`, `telemetry_updated`, `pulse_fired`, `alert_raised`, `flight_started`, `flight_ended` |
| `scripts/mission/Scoring.gd` | `compute_score`, `budget_points`, `band_name_for_points` |
| `scripts/core/ExampleFlight.gd` | `fill_reference_flight`, `fill_reference_rocket`, `find_launch_angle_radians`, `launch_apoapsis_radius_meters`, `create_circularizing_pulse`: the reference rocket that reaches orbit, with the launch angle and the pulse that circularise it for a mission (static; used by "Build example rocket" and by `tests/test_integration.gd`) |
| `scripts/orbit/OrbitView.gd` | `configure`, `show_trajectory`, `show_craft`, `show_threats`, `world_to_screen`, `screen_to_polar_angle_radians`, `screen_to_radius_meters` |
| `scripts/core/ScreenLayout.gd` | screen size, mock-up rectangles and colours (constants) |
| `scripts/core/NumberFormat.gd` | `money` ("$12.5M"), `duration` ("4h37m"), `points_total` (whole), `points_row` (at most 1 decimal), `kilometers` ("400km"), `meters_per_second` ("1235m/s"), `signed_difference` ("+42"), `compact`: the short number texts every screen uses (static) |
| `scripts/ui/PixelGlyphs.gd` | `draw_glyph`, `draw_chip`, `draw_text`, `wrap_lines`, `fit_to_width`, `draw_placeholder_badge`, `lamp_glyph_name`, `lamp_color`; constants `COLOR_AMBER` (the one colour added to ScreenLayout's palette, for warnings) and `TEXT_SIZE_PIXELS` (8, the smallest text) |
| `scripts/ui/WarningLamps.gd` | `lamps_from_summary`, `worst_severity_for_stage`, `worst_severity_for_pulse`, `sentences_for_stage`, `counts`: turns `PlanSummary.warnings` into lamps on the screen side (no `PlanSummary` change); T05 can call `worst_severity_for_pulse` for its pulse markers |

## 6. Conventions

### Frame and units
The frame is inertial, two-dimensional, centred on the central body. +x points right and +y points up; angles are measured counter-clockwise from +x. Time is seconds since launch. Physics uses plain 64-bit `float` values, never `Vector2` (it holds 32-bit numbers, too coarse for metres at orbital distances). Convert to `Vector2` only to draw.

### Orbit conventions (T01)
From the GMAT Mathematical Specifications (NASA GSFC draft), section 4.1.2, Table 4.3. In two dimensions only its two "equatorial" cases apply:

| Case | Argument of periapsis | True anomaly |
|---|---|---|
| Eccentricity ≥ 10⁻¹¹ | angle from +x to the eccentricity vector | angle from the eccentricity vector to the position; add the quadrant fix when the craft is moving inward |
| Eccentricity < 10⁻¹¹ | 0 | angle from +x to the position |

- A clockwise orbit sets `is_clockwise`. Its angles are measured along the motion, as in GMAT's inverse conversion with inclination 180°: with `s = +1` for a counter-clockwise orbit and `s = −1` for a clockwise one, the polar angle of the craft is `s·(ω + ν)`, the periapsis direction is `s·ω` and the apoapsis direction is `s·ω + π` (ω = `argument_of_periapsis_radians`, ν = `true_anomaly_radians`). Example: periapsis drawn at 30° with clockwise motion gives ω = 330°.
- An orbit is **open** when its specific energy is zero or positive. Open orbits have `is_open` set, a negative semi-major axis, and `INF` for period and apoapsis.
- `OrbitState` is the truth. Elements are always computed from it.

### Pulse rule (T01, T05)
- A pulse fires at the first moment after the previous burn when the craft crosses the direction `polar_angle_radians`, after `extra_revolutions` full orbits. The order of `MissionPlan.pulses` is the firing order.
- `delta_v_along_velocity_meters_per_second` points along the motion. `delta_v_outward_meters_per_second` is perpendicular to it, pointing away from the central body (GMAT's V and B directions).
- A pulse with `fires_immediately` set ignores the angle and fires at the current position. Only emergency pulses use it.
- A pulse whose `polar_angle_radians` is within 10⁻⁹ rad of the craft's current direction fires at once, so two pulses placed at one point (staging) fire together.
- When the craft never reaches the angle (impact or escape first), the trajectory status is `UNREACHABLE_PULSE`.
- `Kepler.seconds_until_polar_angle` has no body, so it cannot see the ground: it returns INF only for open orbits and radial paths, never for an impact. Compare its result with `Kepler.seconds_until_impact` (and `seconds_until_escape`), as `OrbitModel.build_trajectory` does.

### Rocket rules (T02)
- `RocketDesign.stages[0]` is the bottom stage and fires first.
- A liquid engine's propellant is in its tank part. A solid motor carries its own. Tanks start full.
- Firing a stage drops every stage below it, with whatever propellant they still hold. A stage that runs empty is dropped.
- Launch stages (`MissionPlan.launch_stage_ids`) burn completely. Their velocity change minus the mission's `launch_loss_meters_per_second` is the burnout speed.
- A solid motor fires once and burns everything: the pulse gives only the direction.
- A liquid engine delivers the requested velocity change, or as much as its propellant allows (`is_pulse_affordable` is then false).
- `PlanSummary.blocking_problems` holds the sentences of `PlanSummary.warnings` that stop a launch. Launch is disabled when it is not empty. Advice in `warnings` starts with `"Warning:"` (`RocketModel.WARNING_PREFIX`) and does not block; nothing decides by that text.

### Display mapping (T05)
Altitude is exaggerated so low orbits are visible. A point at true distance `radius_meters` from the body's centre is drawn, in the same direction, at
```
drawn_radius_pixels = body_radius_pixels + pixels_per_kilometer × altitude_kilometers
```
from the centre of the `OrbitView`. Both numbers come from the mission's `display` entry. Paths are drawn as lines through sampled points, never as ellipses, because the stretched curve is not an ellipse.

### Screen layout
The canvas is 640×400 pixels: five times Amit's 128×80 mock-ups in `design/`. Use the rectangles and colours in `ScreenLayout.gd`. `CONSOLE_SWITCH_RECT` (top right) belongs to the console shell on every screen.

### Text on screen (design/minimize_text_walls_options.md)
- Numbers go through `NumberFormat`: no raw seconds, no four-decimal scores.
- Nothing smaller than 8 pixels. Glyphs are 7×7 on the pixel grid with a 1 pixel dark outline (`PixelGlyphs`), and a glyph always stands with its number and unit.
- Colour is never the only signal: warning lamps differ by shape (✖ blocking, ▲ warning, ● OK).
- Colours: `ScreenLayout`'s plus `PixelGlyphs.COLOR_AMBER` for warnings.
- Catalogue text starting with "Placeholder" is shown without that word, next to a grey PLACEHOLDER badge.

### Flight time (T03, T07)
`FlightSimulation` advances in fixed steps of `SIMULATION_STEP_SECONDS` of simulated time and emits `simulation_step` once per step, at any time scale. Random rolls and collision checks happen per step, never per drawn frame, so the odds do not depend on frame rate or time scale. An event with rate `events_per_hour` happens in one step with probability `1 − e^(−events_per_hour × step_seconds / 3600)`.

### Telemetry channels (T03, T08)
The channel names are the `CHANNEL_…` constants in `TelemetryFrame.gd`; each name ends in the unit of its value. A telemetry part's `stats.channel` is one of those names, or `"radar"` or `"computer"`. A channel with no installed part has `is_sensor_installed` false and the panel shows "NO SENSOR". The acceleration channel needs no part.

### Event log (T03, T07, T04)
One Dictionary per event; the keys are listed in `FlightResult.gd`.

### Side-quest conditions (T04)
`condition.type` is one of: `reserve_delta_v_at_least`, `reserve_delta_v_at_most` (both with `delta_v_meters_per_second`). T04 may add types and must list them here through a contract request.

## 7. Data files
All four are JSON lists of entries with a unique `"id"`. The seed entries in the skeleton are valid examples of every key.

**`data/parts.json`**: `id`, `category` (`engine`, `tank`, `telemetry`, `science`), `name`, `tier` (1 to 3), `cost_million_usd`, `dry_mass_kilograms`, `icon_path`, `tradeoff`, `source`, `is_approximate`, `mission_fit` (science mission id → 0 to 3), `stats`:
- engine: `engine_type` (`solid` or `liquid`), `specific_impulse_seconds`, `thrust_kilonewtons`, and for solids `propellant_kilograms`
- tank: `propellant_capacity_kilograms`, `pressurization` (`regulated` or `blowdown`)
- telemetry: `channel`, `range_kilometers`, `noise_fraction`, `updates_per_second`, `resolution_level` (0 blip, 1 distance and bearing, 2 shape and speed), `dropout_probability`
- science: `power_watts`, `data_rate_megabits_per_second`, `science_value`

**`data/missions.json`**: `id`, `name`, `briefing`, `body_id`, `launch_site.polar_angle_degrees`, `launch_loss_meters_per_second`, `target` (`altitude_kilometers`, `altitude_tolerance_kilometers`, `eccentricity`, `eccentricity_tolerance`), `duration_seconds`, `budget_million_usd`, `display` (`body_radius_pixels`, `pixels_per_kilometer`, `altitude_ring_kilometers`), `science_missions` (`id`, `name`, `description`, `zone`, `required_coverage_fraction`, `required_data_megabits`), `side_quests` (`id`, `name`, `description`, `grant_million_usd`, `condition`, `related_event_type_ids`, `related_multiplier`, `unrelated_bonus`), `hazard_zones`, `hazard_rates` (event type id → list of `inner_altitude_kilometers`, `outer_altitude_kilometers`, `events_per_hour`), `ground_stations`.

**`data/bodies.json`**: `id`, `name`, `gravitational_parameter_cubic_meters_per_second_squared`, `radius_meters`, `atmosphere_height_meters`, `source`.

**`data/event_types.json`**: `id`, `name`, `kind` (`threat`, `fault`, `environment`), `description`, `weight`, `earliest_time_seconds`, `inside_zone_multiplier`.

Adding a key is allowed for the file's owner. Renaming or removing one is a contract change.

## 8. Changing a contract
Do not edit a file you do not own, and do not change the name, parameters or return type of a public function. If a contract blocks you:
1. Write what you need and why in `tasks/notes/T0N.md` under "Contract requests".
2. Tell your human, who relays it to the integrator.
3. Meanwhile, work around it inside your own files.

Adding a new function to your own module is fine. Say so in your notes so others can find it.

## 9. Hand-back files
The hackathon rules require a record of AI use and of every external resource. Each task writes its own files, so no two agents edit the same one:
- `docs/ai_usage/T0N.md`: date, tool and model, what it was asked to do, which files it produced, what a human reviewed or changed.
- `docs/references/T0N.md`: every external resource used (data source, document, code, image, font): name, URL, licence, where it is used.
- `tasks/notes/T0N.md`: what is done, what is not, deviations from the task file, new functions, contract requests.

A task is not finished until all three exist.

## 10. Automatic planning revision (T05, user-approved 2026-11-15)

This section supersedes manual launch selection and explicit pulse-stage assignment for normal gameplay. Original manual helpers remain available only through MissionPlan.PlanningMode.LEGACY_MANUAL; MissionPlan.legacy_plan() creates that explicit compatibility mode.

- MissionPlan defaults to AUTOMATIC and a 30-degree burnout angle. launch_stage_ids and Pulse.stage_id remain legacy data; screens do not select pulse engines in automatic mode.
- SequentialPropulsion is mass-only, using RocketModel's unchanged primitives. It consumes the lowest attached stage, separates it at exhaustion, and continues a demand through successors. Failed attached stages block upper-stage ignition.
- A pulse beginning on a solid burns one complete motor, direction only. A liquid demand can cross into a solid; if demand remains at ignition, that solid burns fully and may overshoot. All contributions share the same pre-pulse inertial thrust direction.
- AscentPlanner returns AscentResult: departure and insertion allocations, actual trajectory/entry state, remaining vehicle, per-stage ascent usage, and failure explanations. Initial thrust must exceed initial weight to report successful lift-off. Thrust failure is a predicted launch failure, not an additional structural Launch-button blocker.
- Departure geometry targets the mission altitude at apoapsis, followed by circularizing insertion. Solid overshoot is propagated honestly. The existing fixed loss allowance, spherical two-body model and impact boundary are retained.
- All liquid engines are assumed restartable without limits. Manoeuvres remain instantaneous. Departure duration is the pre-coast launch readout; later burn durations are readouts without delaying their impulsive state changes.
- PlanResolver resolves automatic manual pulses chronologically, checking reachability before burning fuel. Pulses blocked by an earlier unreachable pulse consume nothing. PlanSummary arrays retain original manual indices.
- PlanSummary.ascent and pulse_allocations expose detailed BurnAllocation objects. mass_after_ascent_kilograms and mass_after_pulse_kilograms are separate from launch/design wet_mass_kilograms and dry_mass_kilograms.
- Separating a spent stage removes engine/tank dry mass after the propulsive mass ratio is evaluated. Separation alone supplies no delta-v.
- TrajectorySegment.source_stage_id and is_automatic_ascent are optional rendering metadata. Automatic burns use no player-pulse indices.
- Flight execution uses the same allocator against live vehicle state. pulse_fired remains one aggregate event per player/emergency pulse; automatic manoeuvres and contributing stages are logged separately.
- OrbitView keeps its seven existing functions and adds show_ghosts, pick_path and stage_color. Display scales are specified at ORBIT_PLANNING_VIEW_SCREEN size and scale proportionally at other widget sizes. Callers should pass the full mission rather than pre-shrinking its display scale.
- T06 owns stat chips/back/zoom. T05 owns only the detailed view and editor. Manual pulse placement during the climb is outside this revision.
