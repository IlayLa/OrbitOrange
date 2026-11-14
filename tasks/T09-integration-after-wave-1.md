# T09 · Integration pass after wave 1

**Branch:** `integration/after-wave-1`, cut from `main` at `c535139`.
**Owner:** the integrator. **Must be merged before** any wave 2 task (T05–T08) starts.

## Goal
T01–T04 are merged and each is sound on its own. Nobody has yet shown that they work together: no real rocket has been flown from the pad to an orbit and scored. This task proves that, fixes the defects the review found, and brings the shared files up to date, so that wave 2 starts from a verified base.

## Rules
- Follow `tasks/CONTRACTS.md` and the naming rule: full words, units written out in names (`_meters`, `_meters_per_second`, `_kilograms`, `_seconds`, `_radians`), no abbreviations, no single-letter variables, in tests too.
- Change only the files named in the steps below. Do not change any public function signature.
- Do **not** change the scoring rules (`scripts/mission/Scoring.gd`), the screen size or the window settings.
- Do not push, and do not merge into `main`. Commit on the branch only.
- If the integration test of step 2 fails because of a defect in `Kepler`, `OrbitModel`, `RocketModel`, `FlightSimulation` or `Scoring`, **stop and report the failure with its numbers**. Do not patch another task's logic to make the test pass (the three fixes of step 4 are the only allowed edits to `FlightSimulation.gd`).

## How to check
Godot 4.7.2 is at `C:\dev\Godot\Godot_v4.7.2-stable_win64_console.exe`. From the repository root:

Git Bash:
```bash
tools/check_project.sh
```
PowerShell:
```
tools\check_project.ps1
```
Each imports the project, runs every `tests/test_*.gd` and runs every scene for a moment. In a fresh worktree the first run builds the `.godot/` cache.

## Steps

### 1. Fix the PowerShell check
`tools/check_project.ps1` reports "tests FAILED" although every check passes: its filter `-match "ERROR"` ignores case and trips on passing lines such as "position error 0.0000001 m". Change it to `-cmatch "ERROR"`. Afterwards both scripts must end with "All checks passed."

### 2. Add `tests/test_integration.gd`: a real flight from the pad to a score
Use only public functions. Save and restore `GameState` fields the test changes, as `tests/test_flight_simulation.gd` does. Create the flight with `preload("res://autoload/FlightSimulation.gd").new()` and `free()` it at the end, as that file does.

**Winning flight.** Mission `low_earth_orbit_placeholder`, science mission `earth_imaging`, no side quests.
- Rocket (T02's reference design, 16.5 million USD):
  - stage 1, fires at launch: `engine_liquid_basic` + `tank_aluminium_basic`
  - stage 2: `engine_liquid_small` + `tank_aluminium_blowdown`
  - payload: `science_camera_basic`, `telemetry_altimeter_basic`
- Launch angle: the one whose apoapsis is at the mission's target altitude, found by bisection between 1° and 89° (apoapsis rises with the angle). For one candidate angle:
  ```
  burnout speed  = RocketModel.summarize_plan(design, plan, launch loss).burnout_speed_meters_per_second
  launch state   = Kepler.launch_state(body, launch site angle, burnout speed, candidate angle)
  elements       = Kepler.elements_from_state(μ, launch state)
  apoapsis       = elements.apoapsis_radius_meters
  ```
- One pulse on stage 2 at the apoapsis, sized to make the orbit circular:
  ```
  polar angle of apoapsis = ω + π          (counter-clockwise launch; wrap to 0..2π)
  speed at apoapsis       = |h| / r_a      (h = Kepler.signed_angular_momentum(launch state))
  Δv along velocity       = √(μ / r_a) − speed at apoapsis
  ```
- Fly: `start_flight(design, plan, mission, seed)`, then `advance_simulation` at time scale 1 until `flight_ended` fires. Score with `GameState.finish_flight(result)`.
- Expect:
  - `end_reason == MISSION_COMPLETED` and `did_reach_orbit`
  - final semi-major-axis altitude within the mission's `altitude_tolerance_kilometers` of the target, eccentricity within `eccentricity_tolerance`
  - `data_delivered_megabits` at least the science mission's `required_data_megabits`
  - total score at least 70 (band "Success" or better)
- By hand arithmetic (not yet confirmed by a run) the numbers should be near: burnout 4654 m/s, launch angle about 30°, pulse about 3880 m/s, reserve about 4440 m/s, score about 97. Print the real values in the check descriptions and put them in your report.

**Failing flight.** `engine_solid_basic` + `science_camera_basic`, the stage fires at launch, launch angle 30°, no pulse. Expect `LAUNCH_FAILURE`, `score.is_launch_failure` and a total of exactly 0.

### 3. Make the stub playable to a win
- Put the search of step 2 in a new shared helper `scripts/core/ExampleFlight.gd` (`class_name ExampleFlight`, static functions, doc comments). It fills a `RocketDesign` and a `MissionPlan` with the reference rocket, the launch angle and the circularising pulse for a given mission. The test of step 2 uses it too.
- In `scripts/design/PlanningConsole.gd` (still the stub; T06 replaces it), make "Build example rocket" call the helper and then both `GameState.notify_design_changed()` and `notify_plan_changed()`.
- Do not open a game window; the integrator checks the screen by hand afterwards.

### 4. Three fixes in `autoload/FlightSimulation.gd`, each with a check in `tests/test_flight_simulation.gd`
- **Low-fuel alarm.** Today it triggers below 10 % of the propellant at launch, so it stays on from stage separation to the end (the reference rocket's second stage holds 7 % of the total). Measure it against the full capacity of the stages still attached: `RocketModel.full_propellant_kilograms` summed over the stages not yet dropped. No alarm when nothing is attached.
- **Science data.** Count only science instruments whose `mission_fit` for the chosen science mission is above 0. The existing test camera has no `mission_fit`; give the fixture one for its test science mission.
- **Repeated rules.** Replace the local 20-radius escape distance and the local "periapsis above the atmosphere" test with `OrbitModel.escape_radius_meters(body)` and `OrbitModel.impact_radius_meters(body)`.

### 5. `data/parts.json`: make the `space_weather` science mission choosable
Add a `space_weather` rating to the `mission_fit` of every science part: `science_magnetometer` 3, `science_atmosphere_probe` 2, the two cameras and `science_imaging_radar` 0. These are game values; say so in each part's `source`.

### 6. Bring the contract files up to date
- `tasks/CONTRACTS.md`:
  - the field `PlanSummary.blocking_problems` (Launch is disabled when it is not empty; advice in `warnings` starts with `"Warning:"` and does not block)
  - `Kepler.seconds_until_impact`, `Kepler.seconds_until_escape`, `OrbitModel.impact_radius_meters`, `OrbitModel.escape_radius_meters`, `FlightSimulation.advance_simulation`, and the new `ExampleFlight`
  - clockwise orbits: ω and ν are measured along the motion; polar angle = s·(ω + ν), periapsis direction = s·ω, apoapsis direction = s·ω + π, with s = +1 counter-clockwise and −1 clockwise (replace the "angles are mirrored" wording)
  - a pulse whose polar angle is within 10⁻⁹ rad of the craft's current direction fires at once
  - `Kepler.seconds_until_polar_angle` cannot see the ground; compare it with `Kepler.seconds_until_impact`
- `scripts/core/types/OrbitElements.gd`: the comment on `argument_of_periapsis_radians` says it is measured in the direction of motion.
- `tasks/T05-orbit-planning-screen.md`: the three orbit points above that T05 needs.
- `tasks/T06-rocket-design-and-planning-overview.md`: Launch is gated by `summary.blocking_problems`, not `summary.warnings`.
- `tasks/T07-events-and-emergency-maneuver.md`: the hazard-near alarm fires within 10 km even without a radar; the onboard-computer parts have no effect until the solar flare uses them; an emergency pulse restarts the revolution count of the planned pulses after it.
- `tasks/README.md`: one line listing T09.

### 7. Commit what Godot generates
After the checks have run, `git status` shows files Godot wrote: a rewritten `project.godot` (it drops `window/stretch/aspect="keep"`, the default, and reorders one line) and `.import` files for the newest images in `design/`. Commit them. Add `.claude/` to `.gitignore`.

### 8. Record the work
Add an entry to `docs/ai_usage/T00.md`: date, tool and models, what was done, which files, and that a human has not reviewed it yet. Write `tasks/notes/T09.md`: what was done, the real numbers of the winning flight, anything that deviates from this file, anything left open.

## Out of scope
- Scoring after a collision or a crash (an open question for the team).
- Any change to window size, scaling or fullscreen.
- The real T05–T08 screens.

## Definition of done
- `tools/check_project.sh` and `tools/check_project.ps1` both end with "All checks passed."
- `tests/test_integration.gd` passes, and `tasks/notes/T09.md` states the numbers it measured.
- `git diff main --stat` lists only files named in this task.
- Nothing is pushed.
