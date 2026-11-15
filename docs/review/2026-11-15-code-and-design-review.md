# Code and design review · 2026-11-15

Reviewed commit: `6dc59c6` (tip of `main`). This file is written for the agents that will do the fixes; every finding has an id, a location, the evidence, a proposed fix and a way to check it.

Structural problems are **not** in this file. They are in [2026-11-15-structural-problems.md](2026-11-15-structural-problems.md) and are not part of the fix pass.

## 0. Scope, method, limits

**Read in full:** everything in `context/` (notes, `plan_draft.md`, challenge description, judging rules, terms, resources PDF, the organisers' e-mail, the sketch; `index.html` turned out to be a saved Godot documentation page), `tasks/CONTRACTS.md`, `tasks/README.md`, `tasks/notes/T01`–`T09`, `tasks/T09`, `data/*.json`, `docs/AI_USAGE.md`, `docs/REFERENCES.md`, and these scripts: all of `autoload/`, `scripts/core/`, `scripts/rocket/`, `scripts/flight/`, `scripts/screens/`; `scripts/orbit/` except the demo files; `scripts/events/` except `T07Demo.gd`; `scripts/mission/` except `T04Demo.gd` and `GeneratePortraits.gd`; and from `scripts/design/` and `scripts/execution/` every file except those listed next.

**Only skimmed (structure, not line by line):** `RocketStackPreview.gd`, `PartDetailsPopup.gd` (about two thirds read), `SelfDestructButton.gd`, `TemperaturePanel.gd`, `AltitudePanel.gd`, the test files (which behaviour each covers, not each assertion), and about half of the per-task files in `docs/ai_usage/` and `docs/references/`.

**Not read:** the demo scripts (`T0NDemo.gd`, `ExecutionDemoFrames.gd`, `T05Scenarios.gd`, `T05FlowCheck.gd`), the task files `tasks/T01`–`T08`, `docs/T05-test-scenarios.md`, `tools/*.ps1`, `tools/generate_placeholders.gd`, and the `.tscn` files other than `OrbitPlanning.tscn` (so the node tree of `EmergencyOverlay.tscn` was not checked). `design/construction/NASA_Data_Mapping_Rocket_Parts.agent.md` was read only at its head.

**Run:** Godot 4.7.2-stable, Linux, headless. `tools/check_project.sh` passes on the reviewed commit: import, **970 checks, 0 failed**, all 15 scenes for 60 frames. Suspected defects were then reproduced with a temporary probe script run through `tests/TestRunner.tscn` (the probe is not committed).

**Not verified:** anything that needs a rendered window (how screens look, mouse hit-testing, fonts, window scaling), and anything Windows-specific. Findings that depend on that are marked `[UNVERIFIED]`.

Evidence labels used below:

| Label | Meaning |
|---|---|
| `[RUN]` | Reproduced by executing the code; the numbers quoted are measured |
| `[READ]` | Follows deterministically from the code as written; not executed |
| `[CALC]` | Arithmetic on the data files |
| `[UNVERIFIED]` | Expected from engine behaviour or reasoning; a human must confirm |

Priorities: **P0** before the submission or the demo · **P1** visible defect in normal play · **P2** real defect with limited visibility · **P3** polish.

## 1. What to do before the submission (23:59 local, 15 November)

In this order. Items 1 and 2 are the only ones that can lose the submission or break the demo outright.

1. **C-01** Remove the private e-mail from the public repository.
2. **C-02** One line in `project.godot` so the game is usable on a Hebrew-language computer.
3. **B-01**, **B-02**, **B-04** The final screen: junk rows in the event log, "Perfect" never shown, no reason given for a launch failure. This is the screen judges see last.
4. **B-05**, **B-12** Player-facing text that still says "Placeholder" or refers to unfinished work.
5. **B-13** Use the team's own art that is already committed.
6. **C-03** README: the "Current state" paragraph is false, and the page has nothing a judge can use.

Everything else can wait.

## 2. Findings for the fix pass

### Rules for whoever fixes these
- `tasks/CONTRACTS.md` section 10 supersedes sections 2 to 6 for normal gameplay (automatic ascent, sequential staging). The older sections, `context/plan_draft.md` and the `tasks/T0N` files still describe manual launch stages and per-pulse stage choice. **Do not implement against the older text.** See structural note S-02.
- Run the checks with `GODOT_EXECUTABLE=<path> bash tools/check_project.sh` (the script is not executable in git, see B-07). It must end with "All checks passed."
- Add or adjust a test for every behavioural fix. Several tests encode current behaviour (for example unrounded score totals in `tests/test_scoring.gd`, icon files in `tests/test_rocket_model.gd:365`).
- The hackathon rules require an AI-use entry for each session: add one under `docs/ai_usage/`.

### Summary

| Id | P | Evidence | One line |
|---|---|---|---|
| C-01 | P0 | `[READ]` | Private e-mail with personal data is in the public repository |
| C-02 | P0 | `[RUN]` | Under a right-to-left locale every screen's controls land off the canvas |
| C-03 | P1 | `[READ]` | README describes a skeleton with stubs; no stubs exist |
| B-01 | P1 | `[RUN]` | Final event log shows "automatic_staging / Unrecorded / No explanation supplied." for every automatic burn |
| B-02 | P1 | `[RUN]` | A flawless flight is banded "Great Success" and displayed as "100.0000 points"; "Perfect" is unreachable |
| B-03 | P1 | `[RUN]` | Pulses planned after the mission's end never fire; planning shows them as valid |
| B-04 | P1 | `[RUN]` | A launch failure gives no reason; a rocket that cannot lift off ends the game inside the Launch click |
| B-05 | P1 | `[RUN]`/`[READ]` | Space-weather science: stale text, and its data requirement cannot be met |
| B-06 | P1 | `[RUN]` | `TestRunner` hangs forever when a test file has a parse error |
| B-07 | P2 | `[RUN]` | `tools/check_project.sh` is not executable in git |
| B-08 | P2 | `[READ]` | Solar flares and both onboard computers have no effect |
| B-09 | P2 | `[READ]` | Fault messages name stages by internal id, not by position |
| B-10 | P2 | `[READ]` | Sensor noise is multiplicative, so angle sensors are noiseless near zero and radar bearing noise depends on direction |
| B-11 | P2 | `[READ]` | The clock says "Next pulse in none" while the automatic insertion burn is pending |
| B-12 | P1 | `[READ]` | "Placeholder" wording and raw units on the mission screen |
| B-13 | P1 | `[READ]` | Committed team art is unused; the game shows generated placeholders |
| B-14 | P2 | `[CALC]` | The over-temperature alarm fires after every nominal launch |
| B-15 | P3 | `[READ]` | Dragging a pulse arrow can request an astronomically large delta-v |
| B-16 | P3 | `[READ]` | Pulse numbers differ between the hint line and the map |
| B-17 | P3 | `[READ]` | "Solid-motor overshoot" warning also appears for a shortfall with no solid motor |
| B-18 | P3 | `[READ]` | Radar shows raw event ids; the seed comment in `GameState` is wrong |
| B-19 | P2 | `[UNVERIFIED]` | Integer scaling may shrink the game to 640×400 on a 768-pixel-high display |

---

### C-01 · P0 · Private e-mail in the public repository
**Where:** `context/Gmail - NASA Space Apps Tel Aviv_ … .pdf`. The repository `IlayLa/OrbitOrange` is public.
**What:** The PDF is a printed private e-mail. It contains personal e-mail addresses of a team member and of an organiser, a video-meeting link with its passcode, and a chat-group invitation link. The participant terms in `context/` list "Personally Identifiable Information" among the things a solution must not include.
**Fix:** `git rm` the file now. Removing it from the tip does not remove it from history; purging history needs `git filter-repo` and a force-push to `main`, which rewrites every branch based on it. **That is a decision for the repository owner, not for a fix agent.** The schedule facts the team needs (deadline, demo format) can be kept as two lines in a text note.
**Also:** `context/index.html` is a 1.3 MB saved copy of the Godot documentation landing page (CC BY 3.0). It is not used; delete it or list it in `docs/references/`.

### C-02 · P0 · Right-to-left locale moves every control off the canvas
**Where:** `project.godot` (no `[internationalization]` section); every screen built in `_ready` with `position = …` before `add_child`.
**Evidence `[RUN]`:** with `TranslationServer.set_locale("he")`, the x position of "Start new game" is 755 instead of 245; "Accept mission" 942 instead of 426; "Back to main menu" 908 instead of 426; the console switch 1097 and 1159 instead of 520 and 579. The canvas is 640 wide, so none of them is visible. `PlanningConsole`, `RocketDesign` and `ExecutionConsole` set their own `layout_direction`; `MainMenu`, `MissionSelect`, `FinalScreen`, `Console` and the emergency overlay do not. T06 reported this as contract request 1; it was never applied.
**Fix (verified):** append to `project.godot`:
```
[internationalization]

rendering/root_node_layout_direction=1
```
With this line the same probe gives 245, 426, 520, 579 under locale `he`, and all 970 checks still pass. The per-screen `layout_direction = LTR` lines can stay.
**Check:** run the game with `--language he`; the main menu button must be in the middle of the window.

### C-03 · P1 · README is out of date
**Where:** `README.md:46`.
**What:** "The project is a walking skeleton … most modules are placeholders marked `STUB(T0N)`". A search for `STUB(` finds nothing in the code. The page also has no description of the game a judge could read, no screenshot, and says no licence has been chosen (the terms then apply Apache 2.0).
**Fix:** rewrite "Current state"; add what the game is, how to play one mission, and the NASA resources used (from `docs/references/`). State the licence decision.

### B-01 · P1 · Junk rows in the final event log
**Where:** `autoload/FlightSimulation.gd:730-734` writes rows with the keys `time_seconds, event_type_id ("automatic_staging"), description, stage_id, delta_v_meters_per_second, propellant_used_kilograms`. `scripts/mission/FinalScreen.gd:85-96` reads `outcome`, `explanation`, `did_player_react`, `delta_v_spent_meters_per_second` and looks the name up in `data/event_types.json`. The documented row format is in `scripts/core/types/FlightResult.gd:28-29`.
**Evidence `[RUN]`:** a normal automatic flight ends with three such rows. Each is shown as `automatic_staging / Unrecorded`, `Reaction: observed; delta-v spent: 0.00 m/s`, `No explanation supplied.` The useful sentence in `description` ("Automatic departure: stage 1 delivered … m/s, consumed … kg.") is never displayed.
**Fix:** write the rows in the documented format: `outcome` = "Burn", `explanation` = the current `description`, `did_player_react` = false, `delta_v_spent_meters_per_second` = the delivered value; keep the extra keys if wanted. In `FinalScreen`, give `automatic_staging` a readable name ("Engine burn"), or add it to `data/event_types.json` with a `kind` that `EventDirector` does not roll (it only rolls ids listed in a mission's `hazard_rates`, so an extra entry is safe; confirm `tests/test_events.gd` still passes).
**Check:** fly the example rocket; the event log lists departure and insertion in readable sentences.

### B-02 · P1 · "Perfect" cannot be reached
**Where:** `scripts/mission/Scoring.gd:99-101` (sum), `:110-121` (bands), `scripts/mission/FinalScreen.gd:67,81` (`%.4f`).
**Evidence `[RUN]`:** the example rocket with `science_camera_high_resolution` scores full marks on all nine lines. The printed total is `100.000000000000` and the band is "Great Success". The sum of floating-point lines is a hair below 100, and "Perfect" requires `>= 100.0` exactly.
**Fix:** compare with a tolerance in `band_name_for_points`: "Scientific Breakthrough" above `100 + 1e-6`, "Perfect" at or above `100 − 1e-6`. Do not round `total_points` itself: T04 decided to keep unrounded totals and `tests/test_scoring.gd` checks them. Display one or two decimals instead of four.
**Check:** the same flight shows "Perfect / 100.0 points" with the "perfect" portrait.

### B-03 · P1 · Pulses after the mission's end are planned but never flown
**Where:** `scripts/core/PlanResolver.gd:66-143` knows nothing about `duration_seconds`; `autoload/FlightSimulation.gd` ends the flight at `_mission_duration_seconds`.
**Evidence `[RUN]`:** mission 1 (duration 16 635 s), example rocket, five pulses of 1 m/s each almost one revolution apart. Planned burn times: 7 406, 12 878, 18 352, 23 829 s … Planning reports no warning and marks all five affordable. In flight 3 of 5 fire. The readouts (apoapsis, periapsis, reserve) and the drawn final orbit describe a state the flight never reaches. The orbit editor has no control for `extra_revolutions`, so each pulse comes at most one revolution after the previous one; from the third pulse on this is easy to hit.
**Fix:** in `PlanResolver.resolve` (it has the mission), after the chain is built, find the segments that end in `NEXT_BURN` at or after `duration_seconds`; add `"Warning: Pulse N fires after the mission ends."` to `summary.warnings` and expose the first such index (a new `PlanSummary` field) so `OrbitPlanning._draw_overlay` can draw those pulses red. Better still, compute the readouts from the orbit at mission end.
**Check:** the scenario above shows the warning and two red pulses.

### B-04 · P1 · Launch failure without a reason; instant game over when thrust is too low
**Where:** `autoload/FlightSimulation.gd:125-126`, `scripts/screens/Console.gd:72-81`, `scripts/mission/FinalScreen.gd:59-63,73-75`.
**Evidence `[RUN]`:** `engine_liquid_hydrogen` + `tank_aluminium_basic`. Planning shows `Warning: INSUFFICIENT LIFT-OFF THRUST` in white and Launch stays enabled (`blocking_problems` is empty; this is the T05 decision). `start_flight` then emits `flight_ended` before it returns: duration 0, empty event log. The player goes from the Launch click straight to "Rocket didn't launch successfully / Score: 0" and "Launch failure overrides every score component". The same two sentences are all a player gets for the other launch failures (not enough delta-v, insertion short). Nothing says why, and the design is lost: the only way on is the main menu.
**Fix, minimum:** before `end_flight` on a launch failure, `log_event` a row in the documented format whose `explanation` is `summary.ascent.failure_reason` plus the numbers already known (thrust against weight; delivered against required departure delta-v). Show that row on the launch-failure screen instead of hiding the log. For failures that end in an impact, log the reason when the arc is rebuilt (`_rebuild_automatic_trajectory`, the branch where `orbit_entry_state` is null or the insertion is unsatisfied).
**Fix, better:** when `summary.ascent.failure_reason` is not empty, Launch asks for confirmation ("The prediction says this rocket will not reach orbit: … Launch anyway?").
**Check:** the rocket above ends on a screen that says the thrust was below the weight, with both numbers.

### B-05 · P1 · Space-weather science mission
**Where:** `data/missions.json`, mission `higher_earth_orbit_placeholder`, science mission `space_weather`.
**What:** (a) its description still reads "awaits a compatible instrument from T02" and the briefing "a future space-weather payload", although T09 made the magnetometer (3 stars) and the atmosphere probe (2 stars) fit. (b) `[RUN]` flying both instruments for the whole mission delivers 1 235 megabits of the 5 000 required: 0.99 of 4 points. The magnetometer alone (0.01 Mb/s) delivers about 190. The requirement was copied from the imaging mission, whose camera produces 1 Mb/s.
**Fix:** data only. Rewrite the two sentences; set `required_data_megabits` to something one fitting instrument can meet in the mission (the magnetometer needs it at or below about 150; or raise both instruments' `data_rate_megabits_per_second`).

### B-06 · P1 · The test runner hangs on a parse error
**Where:** `tests/TestRunner.gd:21-22`.
**Evidence `[RUN]`:** a test file with a syntax error makes `load` return an unusable script, `.new()` raises a script error inside `_ready`, and `get_tree().quit` is never reached. The process had to be killed after 40 s; `tools/check_project.sh` has no timeout, so it waits forever. T06 reported this as contract request 3.
**Fix:** if `test_script == null or not test_script.can_instantiate()`, record a failed check and continue; the runner then exits with code 1. Optionally run Godot under `timeout` in the two check scripts.

### B-07 · P2 · `tools/check_project.sh` is not executable
**Evidence `[RUN]`:** git mode `100644`; `tools/check_project.sh` fails with "Permission denied" on Linux and macOS (Git Bash on Windows ignores the bit, which is why nobody saw it).
**Fix:** `git update-index --chmod=+x tools/check_project.sh`.

### B-08 · P2 · Solar flares and onboard computers do nothing
**Where:** `scripts/events/EventFaults.gd:122-124`, `autoload/EventDirector.gd:262,415`; `FlightSimulation` has neither `set_telemetry_interference` nor `refresh_flight_forecast` (T07 contract requests 1 and 2, never applied).
**What:** a solar flare is only a log line ("Telemetry interference is unavailable on this flight."). `telemetry_computer_basic` ("glitches when the Sun acts up") and `telemetry_computer_hardened` ("Keeps every panel steady through a solar flare", 3 million USD) are read only by `EventFaults._computer_protection_factor`, whose result goes nowhere. They cost money and count as instruments that can fail.
**Fix:** implement `FlightSimulation.set_telemetry_interference(noise_fraction_addition, dropout_probability_addition)` as T07's notes specify: store the two numbers, pass them to `TelemetryFeed.sample`, add them to `noise_fraction` and to `dropout_probability` (clamped to 1), reset them in `start_flight`. `tests/test_events.gd` already exercises the hook through a fixture. `refresh_flight_forecast` is less urgent: without it only the *predicted* path after a fault is stale; the burn itself uses the live vehicle.
**If there is no time:** remove the two computers from `data/parts.json` and the `solar_flare` rates from both missions, so the game does not sell a part that does nothing.

### B-09 · P2 · Fault messages use the stage id, not the stage number
**Where:** `scripts/events/EventFaults.gd:98,100,117` format `"Stage %d"` with `stage_id`.
**What:** everywhere else "Stage N" is the position in the stack (`RocketModel`, the planning screens, the emergency overlay). Ids only grow: build three stages, remove the first, and the remaining two have ids 2 and 3. The log then says "Stage 3 can no longer fire" about a two-stage rocket.
**Fix:** `SequentialPropulsion.stage_number(vehicle.design, stage_id)`.

### B-10 · P2 · Multiplicative sensor noise
**Where:** `scripts/flight/TelemetryFeed.gd:164-166` (`value * (1 + noise_fraction * random)`), used for every channel and at `:155` for the radar bearing.
**What:** an error proportional to the value is zero when the value is zero. On a circular orbit the flight-path angle and the attitude are 0, so the sun sensor (2 % noise) and the star tracker (0.1 %) both read exactly `+0.0°`: the tier makes no visible difference in the nominal case. For the radar bearing the error grows with the absolute inertial bearing: none for a contact towards +x, up to ±36° (20 % of 180°) for one towards −x, with wrap-around at ±180°.
**Fix:** additive noise for the three angle quantities: `value + noise_fraction * reference * random`, with a reference such as `PI / 2` for the two angle channels and `PI` for the bearing. Keep multiplicative noise for altitude, fuel, range and closing speed. `tests/test_flight_simulation.gd` has noise checks that may need new bounds.

### B-11 · P2 · "Next pulse in none" before the insertion burn
**Where:** `autoload/FlightSimulation.gd:371-377` returns INF while `_automatic_insertion_pending`; `:559` puts that in the frame.
**What:** during the launch burn and the whole coast to apoapsis the clock reads "Next pulse in none", then the simulation drops to 1× ten seconds before a burn the display never announced. During the launch burn the craft also stays at altitude 0 with speed 0 and then has burnout speed at once (T08 recorded this; it follows from the impulsive ascent model, see S-10).
**Fix:** `frame.seconds_until_next_pulse = min(next planned pulse, _automatic_insertion_time_seconds) − now`. The launch-burn readout is a larger change; leave it.

### B-12 · P1 · Placeholder wording on the mission screen
**Where:** `data/missions.json` (every `briefing` and `description` starts with "Placeholder", names such as "First orbit" sit beside ids ending in `_placeholder`), `scripts/mission/MissionSelect.gd:56,60` ("REGIONAL HAZARDS (placeholder rates)", "DURATION 16635 seconds").
**Fix:** rewrite the texts (ids can stay: tests and `ExampleFlight` use them). Show the duration as hours and minutes, or as "about 3 orbits". Drop "(placeholder rates)" from the screen; say it in `docs/references/` instead.

### B-13 · P1 · Team art is committed but not used
**Where:** `design/amit sprites/*.png` (five 128×80 portraits), `design/construction/engines/*.png` (seven 64×64 engines), `design/construction/materials/*.png` (three 64×64 tank materials), `design/buttons.png`. The game uses `assets/placeholders/portraits/*.png` (32×32, generated) in `scripts/mission/FinalScreen.gd:4-11` and `assets/placeholders/parts/*.png` (16×16, generated) through `icon_path` in `data/parts.json`.
**Fix:** data and one constant.
- Engines: `engine_cold_gas` → `engine_coldgas.png`, `engine_solid_kick` → `engine_star37.png`, `engine_solid_basic` → `engine_star48.png`, `engine_solid_booster` → `engine_orion.png`, `engine_liquid_small` → `engine_rutherford.png`, `engine_liquid_basic` → `engine_merlin.png`, `engine_liquid_hydrogen` → `engine_RL10.png`.
- Tanks: aluminium → `materials_aluminum.png`, aluminium-lithium → `materials_Al-Li.png`, composite → `materials_carbon.png` (two tanks share each).
- Portraits: there are five drawings for six bands. Suggested: Failure → `amit_concerned`, Partial Success → `amit_judging`, Success → `amit_happy`, Great Success, Perfect and Scientific Breakthrough → `amit_greatsuccess`; `amit_explaining` suits the mission-select screen. The figure occupies a small part of the 128×80 frame, so the 72×72 portrait rectangle needs a crop (`AtlasTexture`) or a larger rectangle. **A human must look at the result.**
`tests/test_rocket_model.gd:365` only checks that each icon file exists. `PartCard` and `RocketStackPreview` draw icons at 20 pixels and below; check that 64×64 art survives that.

### B-14 · P2 · Over-temperature alarm on every launch
**Where:** `autoload/FlightSimulation.gd:19-22`.
**`[CALC]`:** heating is 2 K/s during the launch burn. The example rocket's first stage burns for 20 000 kg ÷ (845 000 N ÷ (311 s × 9.80665 m/s²)) ≈ 72 s, so the temperature reaches about 444 K against a threshold of 350 K. The alarm lamp starts flashing 25 s into the burn and keeps flashing for about (444 − 350) ÷ 0.5 ≈ 188 s after it. T08's end-to-end run saw it ("OVER TEMPERATURE listed after the burn"). An alarm that fires in every nominal flight teaches the player to ignore the lamp.
**Fix:** tuning. For example a threshold above the nominal peak, or heating that saturates; then the alarm can mean something (a weakened engine burning longer, a flare).

### B-15 · P3 · Unbounded pulse size from dragging
**Where:** `scripts/orbit/planning/PulseGeometry.gd:34-35`, used at `scripts/orbit/OrbitPlanning.gd:229`. The mapping is exponential and clamped only at `exp(50)`; dragging the arrow across the 465-pixel view requests about 10¹⁷ m/s. The pulse then drains every stage and the spin box shows the number.
**Fix:** clamp the request to the reserve available before that pulse (or to a fixed ceiling such as 20 000 m/s).

### B-16 · P3 · Two numberings for one pulse
**Where:** `scripts/orbit/OrbitPlanning.gd:303` shows `pulse.pulse_id`; the map (`:461`), the mass readout (`:341`) and the warnings use the position in the plan. After inserting a pulse between two others the hint says "Pulse 3" for the one drawn as "2".
**Fix:** use the position everywhere.

### B-17 · P3 · Wrong warning text
**Where:** `scripts/core/AscentPlanner.gd:99-100`. Any initial orbit outside the altitude tolerance gets "Solid-motor overshoot changed the initial orbit altitude.", including a liquid-only rocket whose departure burn fell short and circularised too low.
**Fix:** say what happened: above or below the target, and by how much.

### B-18 · P3 · Small text defects
- `scripts/execution/RadarPanel.gd:118` shows the raw id (`satellite_conjunction`) for level-2 contacts; use the `name` from `GameData.event_type`.
- `autoload/GameState.gd:40` says `random_seed` seeds "all random events". Since T07 it seeds only the telemetry noise; `autoload/EventDirector.gd:136` calls `randomize()`. Fix the comment, or pass the seed through so a rehearsed demo can be repeated (see improvement I-04).

### B-19 · P2 · `[UNVERIFIED]` Window scaling on small displays
**Where:** `project.godot:29-33`: window 1280×800, `stretch/scale_mode="integer"`.
**Concern:** with integer scaling the factor is rounded down. A display 768 or 720 pixels high cannot hold 800, the window is shrunk, and the factor becomes 1: a 640×400 picture in the middle of the screen, with 8-pixel text. Many laptops and projectors are 1366×768 or 1280×720.
**Action:** try the game on the computer and projector used for the demo. If it shrinks, set `scale_mode="fractional"` for the demo. This is an integrator-owned file.

## 3. Design review

These are not coding defects. They are places where the game as built does not yet deliver the trade-offs the challenge asks for ("every major design decision has a consequence", "rarely a single perfect solution"). Each needs a team decision before anyone codes it.

### D-01 · The launch angle has one best value: 0°
`[RUN]` Example rocket, mission 1, launch angle swept:

| Angle | Departure m/s | Insertion m/s | Reserve after ascent m/s |
|---|---|---|---|
| 0° | 9 529 | 118 | 4 846 |
| 15° | 8 019 | 1 748 | 4 726 |
| 30° (default) | 6 190 | 3 850 | 4 452 |
| 45° | 5 142 | 5 250 | 4 102 |
| 60° | 4 581 | 6 223 | 3 689 |
| 80° | 4 256 | 7 222 | 3 015 |

The reserve falls monotonically with the angle. The reason: the ascent is an impulse at the surface, the planner solves for the speed that puts the apoapsis at the target, and `launch_loss_meters_per_second` is a constant that does not depend on the angle. A horizontal launch from the ground is then a Hohmann transfer and nothing penalises it. The slider is a decision without a trade-off (its one real use is to burn off reserve for the "Use the reserve" quest).
**Option:** make the loss depend on the angle, for example a drag term that grows as the launch flattens and a gravity term that grows as it steepens, so that the best angle is interior and moves with thrust-to-weight. This is a `missions.json` key plus a few lines in `AscentPlanner`.

### D-02 · Most instruments cannot help and can only hurt
- Altimeter, attitude sensor, fuel gauge, temperature sensor: they change what a panel shows and nothing else. No outcome depends on them. (The Δv panel is not a sensor channel, so the fuel gauge is redundant for decisions.)
- Both computers: no effect at all (B-08).
- Every installed instrument adds to the denominator of "Vehicle health" and is a target for debris and sensor-failure events. A rocket with **no** instruments gets all 5 health points.
- `[READ]` `science_imaging_radar` (12 million USD, 100 kg) is dominated by `science_camera_high_resolution` (9 million USD, 80 kg): same 3-star fit; its higher data rate is worthless because the basic camera already delivers 16 391 of the 5 000 megabits required (T09 measurement).
- Only the proximity radar changes an outcome (warning time before an encounter).

The stats `power_watts`, `science_value`, `pressurization` and the mission key `ground_stations` are stored and read by no script.

### D-03 · No pressure from budget, mass or delta-v
- `[RUN]` "Build example rocket", then swap the camera for the high-resolution one: 21.5 of 30 million USD and full marks on every line. The best score needs one click and one swap.
- `[RUN]` The example rocket's second stage alone could deliver 8 344 m/s, because the payload weighs about 30 kg against a 1 500 kg tank. Instrument mass (0.05 to 100 kg) barely moves any number the player sees.
- Mission 1's side quest asks for at least 100 m/s of reserve; the example rocket ends with about 4 450. Ticking the box gives +5 million USD and +20 points for nothing.
All numbers in `missions.json` are marked placeholder; this is balance work, not code.

### D-04 · A failed bottom stage disables the whole rocket
`[RUN]` With stage 1 marked failed on the two-stage example rocket, the sequential reserve is 0 m/s ("The current stage has failed; upper stages remain attached.") while stage 2 by itself could give 8 344 m/s. `CONTRACTS.md` section 10 chose this on purpose, but there is no control to drop a failed stage, so planned pulses and emergency manoeuvres all become impossible. `plan_draft.md` wanted the opposite ("Re-plan the remaining pulses with the other engines"). With the placeholder rate (0.03 per hour) an engine malfunction happens in about 12 % of flights `[CALC]`; a first malfunction of a liquid engine only weakens it, so the dead end needs a solid stage or a second hit.
**Option:** drop a failed stage automatically when a burn is demanded, or add "Jettison failed stage" to the emergency overlay.

### D-05 · Scoring loopholes
- `[RUN]` A rocket with **no payload** scores 88.0, "Success": the 8 coverage points only look at the final orbit (`Scoring.gd:84`), not at whether a fitting, working science instrument is on board.
- `[RUN]` A craft destroyed in a collision with 500 m/s left gets the side-quest line "Keep a reserve = 20.0" and a total of 60.33, "Partial Success". Quests are graded on the reserve alone (`Scoring.gd:26,29`), whatever happened to the craft. T04 recorded "grade subscores independently after crash, collision or escape" as a decision; the team should confirm it meant this.
**Options:** coverage requires a working instrument with a fit above 0; quest success requires `did_reach_orbit`.

### D-06 · The execution phase is mostly watching
- There is no map during the flight. The orbit monitor on the planning half is frozen at the plan; the execution half shows numbers and the radar scope.
- The plan is locked at launch. `plan_draft.md` described pulses marked "REVIEW" after an emergency burn that the player keeps, moves or deletes; that was not built.
- `[CALC]` With the placeholder rates a mission 1 flight sees about 2 events (0.455 per hour over about 4.4 hours after the 600 s quiet period), about 1.4 of them encounters. Events are randomised every run, so a five-minute demo cannot count on seeing the emergency manoeuvre, which is the most distinctive part of the game.

### D-07 · The loop ends at the final screen
After any ending the only button is "Back to main menu": mission, rocket and plan are gone. The challenge asks for a game where players "modify their mission design and simulate it multiple times", and the final screen is where the lesson is. `plan_draft.md` deferred the replay loop; it is the highest-value missing feature for the educational aim.

## 4. Possible improvements

Ordered by value for the judging criteria (impact, creativity, validity, relevance, presentation) against effort. None is required to fix a defect.

### Small (about an hour each)
- **I-01 Explain every ending.** One sentence per score line already exists; add the same for the end reason (why the launch failed, what hit the craft, how far the orbit was from the target and what would have fixed it). Builds on B-04.
- **I-02 "Try again" on the final screen:** return to the console with `GameState.design` and `GameState.plan` kept and `has_launched` cleared. `GameState.start_new_game` shows which fields to leave alone.
- **I-03 Show the craft on the overview orbit monitor during the flight** (`OrbitView.show_craft` exists). To keep the rule that screens see only telemetry, add the craft's position to `TelemetryFrame`, degraded like the other channels.
- **I-04 Demo controls.** A fixed event seed and a key that calls `EventDirector.force_event` (both exist for the tests), so the demo can show an asteroid alert on cue.
- **I-05 Show the delta-v the mission needs** next to the delta-v the rocket has (circular speed at the target plus the launch loss), coloured green, amber or red by margin. `plan_draft.md` planned these margins from NASA's Mission Design Lab material.
- **I-06 A web export** (the project already uses the Compatibility renderer), so judges can play from a link. The submission's demo itself must be a 30-second video or at most seven slides.

### Medium
- **I-07 Make telemetry matter.** Examples: without a fuel gauge the Δv panel shows nothing; without an altimeter the automatic insertion happens with an altitude error; the attitude sensor's tier sets a pointing error on every pulse. Each turns a cosmetic part into a decision.
- **I-08 Rate-limited data link** (version 2 in `plan_draft.md`): storage on the computer, a transmitter part, contact only above a ground station. `ground_stations` is already in the mission data and `DataLink.deliver` is the single seam. This adds the communications and data resources the challenge lists and gives the imaging radar a reason to exist.
- **I-09 Power budget:** `power_watts` exists on every science part; add a power source part and a limit.
- **I-10 Surface the NASA data.** `design/construction/NASA_Data_Mapping_Rocket_Parts.agent.md` maps all 29 parts to NASA datasets and NTRS records, but the game shows only the `source` sentence (mostly Wikipedia tables). Putting the NASA reference in the part popup and naming a comparable real mission on the final screen (as NASA's telescope learning game does) speaks directly to the "relevance" criterion. That file says its links were not opened one by one: check them first.
- **I-11 `extra_revolutions` in the orbit editor**, so a pulse can wait an orbit; together with B-03.
- **I-12 Orbit view that fits the path** instead of a fixed scale: a transfer above about 950 km altitude is clipped at the top and bottom of the monitor.
- **I-13 A pixel font.** "Pixel art" is one of the team's absolute truths; all text uses Godot's default font at 8 to 14 pixels.

### Large
- **I-14 Team play.** The challenge description comes back to play for up to four people in almost every section. A hot-seat version with roles (mission planner, rocket engineer, science lead, flight director), each seeing one screen and one budget line, fits the existing split of screens.
- **I-15 Difficulty levels and more missions,** once the balance of D-03 is real; missions are data, so this is content work.
- **I-16 Mission report export** (the score table and event log as a file or image), for comparing designs.

## 5. Checked and found sound
- **Orbit mathematics (`Kepler.gd`, `OrbitModel.gd`).** The elliptic, hyperbolic and parabolic branches of `propagate` match the difference form of Kepler's equation and the Lagrange coefficients; the clockwise convention is consistent between `elements_from_state`, `state_from_elements`, sampling and pulse timing; impact, escape and "pulse not reached" are decided on the same state in planning and in flight. No defect found.
- **Rocket equation and staging (`RocketModel.gd`, `SequentialPropulsion.gd`).** Mass at ignition, jettison order and the liquid-into-solid overshoot behave as `CONTRACTS.md` section 10 says. Planning and flight use the same allocator, so predicted and flown burns agree.
- **Time stepping (`FlightSimulation.advance_simulation`).** Every loop iteration either advances time, consumes a boundary or returns; no path was found that can spin. Cost at 1000×, with every 5 Hz sensor and the long-range radar installed: 2.45 ms per frame on average, 3.9 ms worst `[RUN]` (headless, simulation and telemetry only).
- **Event rolls** are per fixed 5 s tick with `1 − e^(−λΔt)`, independent of frame rate and time scale, as the contract requires.
- **The hand-back discipline** (AI-use and reference files per task) is in place and matches what the terms require.
