# Structural problems · 2026-11-15

Companion to [2026-11-15-code-and-design-review.md](2026-11-15-code-and-design-review.md), reviewed at commit `6dc59c6`.

These are problems in how the project is put together. None of them is a bug by itself, and **none belongs in the pre-submission fix pass**: each is a change across many files that would put the passing checks at risk. They are recorded so that the causes are known when the same kind of defect shows up again, and as a list for after the hackathon.

For a proof of concept built in two days by four agents on four machines, the structure held up well where the contract was explicit (orbit maths, rocket maths, the telemetry boundary). The problems below sit where the contract was changed late or was never written.

| Id | Problem | Defects it has already caused |
|---|---|---|
| S-01 | Two planning models live side by side | — |
| S-02 | The written contract contradicts itself | README (C-03); risk for every future agent |
| S-03 | `FlightSimulation` does seven jobs | B-11, B-14 |
| S-04 | Hidden dependencies between the autoloads; integration seams that were never joined | B-08 |
| S-05 | Untyped dictionaries are the data model | B-01, B-05 |
| S-06 | Things are identified by ids that do not identify them | B-09, D-02 |
| S-07 | Screens are built in code with literal coordinates | C-02 |
| S-08 | Development code sits in the production tree | — |
| S-09 | The test set-up cannot fail fast and shares global state | B-06 |
| S-10 | The ascent model and the "swappable" orbit model | D-01, B-11 |

---

## S-01 · Two planning models live side by side
`MissionPlan.PlanningMode` has `AUTOMATIC` (the game) and `LEGACY_MANUAL` (the first design: the player ticks launch stages and assigns a stage to each pulse). Only tests, demos and `ExampleFlight.fill_reference_*` create legacy plans, but the legacy path is still complete:

- `PlanResolver.resolve` has two bodies (`scripts/core/PlanResolver.gd:12-35`).
- `RocketModel.summarize_plan` (78 lines) is called only by the legacy branch of `PlanResolver` and by `ExampleFlight`'s legacy helpers; the automatic path uses `SequentialPropulsion.base_summary` and `fill_reserve`, which recompute the same cost and mass fields.
- `FlightSimulation` branches on the mode in the launch sequence, the pulse, the trajectory rebuild, the remaining delta-v and the acceleration readout, and keeps two sets of readout state (`_pulse_*` fields and `_readout_stages`).
- `EmergencyOverlay` and `EmergencyManeuver` each have both previews.
- `Pulse.stage_id` and `MissionPlan.launch_stage_ids` are unused in the game, but `RocketDesign.remove_stage` still filters pulses and launch stages by them.
- `tests/test_integration.gd`, the oldest end-to-end test, flies the legacy path; the automatic path is covered by `tests/test_automatic_planning.gd` and `tests/test_t05_scenarios.gd`.

**Cost:** every change to flight or planning must be made, or consciously not made, twice. **Direction:** delete the legacy mode and port the tests that still use it.

## S-02 · The written contract contradicts itself
`tasks/CONTRACTS.md` sections 2 to 6 describe the legacy model as binding ("Launch stages burn completely", "Firing a stage drops every stage below it", file ownership by task). Section 10, appended on the last day as unformatted bullets, supersedes them. `context/plan_draft.md`, the eight task files and the README ("walking skeleton … `STUB(T0N)`") were not updated. The file-ownership table no longer describes who changed what: T05 edited shared types, `PlanResolver`, `FlightSimulation` and T06's and T07's files, with permission recorded only in `tasks/notes/T05.md`. Header comments such as "Owned by the integrator" are stale.

**Cost:** the project's method is "the agent reads the contract first". An agent that reads sections 2 to 6 and stops will implement the wrong game. **Direction:** one current architecture page that replaces sections 2 to 6 and 10; mark `plan_draft.md` and the task files as history.

## S-03 · `FlightSimulation` does seven jobs
740 lines and 39 private fields: launch sequencing, the time loop, planned and emergency burns, trajectory rebuilding, science collection, the thermal model and alarms, telemetry-frame assembly and the flight result. The pieces communicate through fields (`_launch_stage`, `_coast_segment`, `_automatic_insertion_pending`, `_pulse_readout_ends_at_seconds` …) whose valid combinations are not written down. Tests reach into it (`flight._process(…)`, `_create_telemetry_frame()`; 25 private accesses in `tests/test_flight_simulation.gd`), which freezes the internals.

**Direction:** split by job behind the existing signals: a launch sequencer, a burn executor, a science collector, an alarm model. The time loop then only orders boundaries.

## S-04 · Hidden dependencies between autoloads; seams that were never joined
- `FlightSimulation.start_flight(design, plan, mission, seed)` looks self-contained, but `_configure_science` reads `GameState.science_mission_id` and returns silently when `GameState.mission` is a different mission (`autoload/FlightSimulation.gd:584-586`). An isolated flight with the wrong global state collects no science and says nothing.
- `EventDirector` takes mission and quests from `GameState` when bound to the real flight, and from `configure` otherwise: two code paths for the same data.
- `EventDirector` talks to the flight through `has_method("set_telemetry_interference")` and `has_method("refresh_flight_forecast")`. Neither method exists. Duck typing turned a missing integration into silent no-ops (B-08) that no test can catch, because the tests supply a fixture that has the methods.
- `GameState.random_seed` is documented as the seed of everything and seeds only telemetry noise.
- Contract requests were written into nine `tasks/notes` files and several were never applied (T06 requests 1 and 3, T07 requests 1 and 2, T08 requests 1 and 2). There is no list of open requests.

**Direction:** pass everything a flight needs in one typed argument; declare the hooks in the contract and call them directly so a missing one is a parse error; keep one file of open contract requests.

## S-05 · Untyped dictionaries are the data model
Missions, parts, bodies, event types, event-log rows, encounters, radar contacts and readout stages are `Dictionary` values read with string keys and a default at every call site.

- Defaults disagree: `body_id` falls back to `"earth"` in ten places and to `""` in `Scoring.gd:43`; the target altitude falls back to `400.0` in `AscentPlanner` and to `0.0` in `Scoring` and `MissionSelect`.
- `GameData` checks only that each entry has an `id`. A misspelt key in `missions.json` or `parts.json` is not an error; the default is used and the game runs with wrong numbers.
- The event log has two row shapes because nothing defines a row (B-01).
- Data that cannot work is not caught: a science mission whose requirement no instrument can meet (B-05), parts whose stats nothing reads (D-02).

**Direction:** small typed wrappers (`MissionDefinition`, `PartDefinition`, `EventLogRow`) created by `GameData`, which validates required keys and ranges at load and reports the file and entry. One test that every science mission is satisfiable by at least one catalogue instrument.

## S-06 · Ids that do not identify
- **Stages** have a `stage_id` that only grows and a position that changes. Messages for the player need the position; some code formats the id (B-09). Colours are picked by id (`OrbitView.stage_color`), so removing and re-adding a stage changes its colour.
- **Payload instruments** are identified by part id. `VehicleState.is_working_by_instrument` is keyed by it, so two identical instruments share one health flag and count as one installed instrument, while `_science_rates_by_instrument` adds their data rates and the cost and mass count both. `TelemetryFeed` keeps one part per channel. The design screen allows up to ten payload parts including duplicates.

**Direction:** give each installed payload item an instance id, and keep stage position as the only number shown to the player.

## S-07 · Screens are built in code with literal coordinates
Every scene file is an empty root with a script; all controls are created in `_ready` with pixel positions. Consequences:

- Nothing can be adjusted in the Godot editor; the artist cannot move a button.
- The contract says "use the rectangles in `ScreenLayout`"; in practice there are three sources: `ScreenLayout`, `ExecutionLayout` (T08 could not edit the shared file) and inline literals (`scripts/orbit/OrbitPlanning.gd:51-116`, `MissionSelect.gd`, `FinalScreen.gd`, `MainMenu.gd`).
- There are two theme factories (`MissionPresentation.create_theme`, `PlanningStyle.create_theme`) plus per-control overrides; `AlarmPanel` builds a whole theme to copy one style. Font sizes from 8 to 20 are literals.
- Setting positions before `add_child` is what a right-to-left locale mirrors; three screens carry a hand-written workaround and four do not (C-02).
- Godot ignores a size set right after a font override until the next frame (T06 request 4), so some code sets sizes twice.
- The Earth sprite is a region cut out of the orbit mock-up (`OrbitView.gd:26-27`) and the lit lamp a region of the alarm mock-up; "bodies are data" does not hold for anything that is drawn.

**Direction:** one theme resource; layouts as scene files over the mock-up background; a sprite path per body in `bodies.json`.

## S-08 · Development code in the production tree
`scripts/*/T0NDemo.gd`, `ExecutionDemoFrames.gd`, `T05Scenarios.gd`, `T05FlowCheck.gd`, `GeneratePortraits.gd` and `scenes/development/` sit beside game code and would be exported with it. There is no `export_presets.cfg`. `design/` mixes mock-ups used at run time, unused art, an HTML table and an agent instruction file; one folder name contains a space (`design/amit sprites`). `context/` holds saved third-party pages and, until removed, a private e-mail (C-01).

**Direction:** a `development/` root excluded from export; `design/` for source art only, run-time art under `assets/`.

## S-09 · Tests cannot fail fast and share global state
- One process runs every test in one `_ready`. A parse error hangs it (B-06); nothing has a timeout; a crash in one file loses the rest.
- Failure detection in the check scripts is a search for the word `ERROR` in the output. A check description that contains it would fail the run; T09 already had to make the PowerShell search case-sensitive.
- Tests change `GameState`, `GameData` (`register_part`) and `TranslationServer` and put them back by hand. T08 found one leak; nothing detects the next.
- Screen tests call handlers directly and set the zoom time to zero (T06 notes), so real input and animation are covered by one scene, `T05_full_game_check`.
- Coverage follows task boundaries. The defects found in this review are all between tasks: flight log against final screen, events against flight, planning against mission duration, data against scoring.

**Direction:** construct state per test instead of mutating the autoloads; a per-file timeout; a short list of end-to-end checks that go from Launch to the text on the final screen.

## S-10 · The ascent model and the "swappable" orbit model
- **Ascent.** The whole launch is one velocity change applied at the surface radius, minus a constant loss. This was a deliberate simplification in `plan_draft.md`, and three things follow from it: a horizontal launch through the ground is the best launch (D-01); burn durations are display only, so the craft sits at altitude 0 and speed 0 for the length of the first-stage burn and the 3 850 m/s insertion is instantaneous while its "burn" plays on the accelerometer (B-11); thrust matters only as a pass or fail test at lift-off.
- **Orbit model.** `OrbitModel` is described as the one place to change for another gravity model ("the Moon can be added later"). In fact eleven other scripts call `Kepler.propagate` or `Kepler.elements_from_state` directly, among them `FlightSimulation`, `ThreatModel`, `TelemetryFeed`, `AscentPlanner` and `PlanResolver`. Scoring, coverage and the pulse rule are defined on two-body elements. A second body would touch all of them.
- **Time.** The loop mixes fixed 5 s ticks with variable boundaries (sensor samples, burns, the mission end). Collisions found on a tick are applied on the next one, so a burn inside that interval can already have fired (recorded by T07). Asking for a faster time scale within ten seconds of a burn is refused without a message.

**Direction:** if the game grows past low Earth orbit, replace the surface impulse by a short integrated ascent (thrust, gravity, a drag term) that hands a state to the Kepler model, and route every propagation through `OrbitModel`.
