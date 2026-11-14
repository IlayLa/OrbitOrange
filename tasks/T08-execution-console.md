# T08 · Execution console

**Lane D · Wave 2 · Branch `task/T08-execution-console` · Needs: T03 merged into `main`.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Build the control room the player watches the flight from: a wall of instruments whose quality depends on what was bought, a mission clock with time controls, and the objective list.

## Files you own
- `scripts/execution/**` (`ExecutionConsole.gd`, and new files: one per panel)
- `scenes/ExecutionConsole.tscn`
- `scenes/development/T08_demo.tscn` (new)
- `tools/generate_placeholders.gd`
- `assets/placeholders/console/*`, `assets/placeholders/telemetry/*` (new)
- `docs/ai_usage/T08.md`, `docs/references/T08.md`, `tasks/notes/T08.md` (new)

## What you provide
`scenes/ExecutionConsole.tscn`: a full-screen (640×400) `Control` that the console shell places as its right half.

## What you consume
| From | What |
|---|---|
| T03 | signal `telemetry_updated(frame)`: everything you display comes from the `TelemetryFrame`; signal `alert_raised`; functions `set_time_scale`, `pause`, `end_flight`; constant `ALLOWED_TIME_SCALES` |
| Integrator | `GameState.mission`, `GameState.science_mission()`, `GameState.accepted_side_quests()` for the objective list; `ScreenLayout` |

**Read nothing else from `FlightSimulation`.** Its `craft_state` is the truth, and the player must only see what the instruments report.

## Requirements
Design reference: `context/plan_draft.md`, sections "EXECUTION half", "Execution instruments" and "Time controls". Sketch: `context/ScreensDraft.jpeg` (right half). There is no mock-up for this screen yet; match the style of the planning mock-ups (colours in `ScreenLayout`).

1. **Layout** as in the sketch: a left column with the clock, delta-v remaining and the objective list; an instrument wall with ALARM, TEMP, RADAR in the centre, Angles, Altitude, Fuel and Acceleration.
2. **One script per panel**, each with a function that takes a `TelemetryFrame` and redraws.
3. **Sensor states.** For each channel's `TelemetryReading`: `is_sensor_installed` false → "NO SENSOR"; `is_sensor_working` false → "NO SIGNAL"; otherwise the value with its unit.
4. **Radar.** A circular scope with a sweep. Draw each entry of `frame.radar_contacts` at its bearing and range, with the detail its `resolution_level` allows: 0 a blip; 1 a blip with distance; 2 an outline with distance and closing speed. `is_radar_installed` false → "NO SENSOR".
5. **Angles.** Two angles, both relative to the local horizontal: attitude (where the nose points) and flight-path angle (where the velocity points).
6. **Acceleration.** In g (divide by 9.80665). It is active during the launch burn and during pulses and reads 0 otherwise.
7. **Alarm.** A lamp that flashes while `frame.active_alarms` is not empty, with the alarm texts beside it. Show the message of `alert_raised` until the player dismisses it.
8. **Time controls** next to the clock: pause, 1×, 10×, 100×, 1000×, from `ALLOWED_TIME_SCALES`. Highlight the one in `frame.time_scale`.
9. **Left column.** Mission time; `delta_v_remaining_meters_per_second`; time to the next pulse; science data generated and delivered; the objective list (target orbit, the science mission, the accepted side quests).
10. **The self-destruct button** from the team notes: a tempting button in a corner that does not destroy anything. Give it a harmless joke response.
11. **Placeholder art.** Extend `tools/generate_placeholders.gd` to draw the frames, gauges, lamp and static you need, with file names that say what they are, so real art can replace them by file name. It must never overwrite an existing file.
12. Leave `ScreenLayout.CONSOLE_SWITCH_RECT` empty.

## Out of scope
Producing telemetry (T03). The emergency overlay (T07 adds it over your screen by itself).

## How to check your work
- `scenes/development/T08_demo.tscn`: feeds the console a sequence of hand-made `TelemetryFrame` objects (sensor missing, sensor failed, three radar contacts at different resolution levels, an active alarm), so every state can be seen without a flight.
- A human opens the demo and checks each panel in each state.
- `tools/check_project.sh` passes.

## Definition of done
- No `STUB(T08)` remains.
- The demo scene runs and a human has confirmed every panel state.
- The three hand-back files exist.
