# T07 · Random events and the emergency maneuver

**Lane C · Wave 2 · Branch `task/T07-events-and-emergency-maneuver` · Needs: T01, T02 and T03 merged into `main`.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Make the flight more than a replay of the plan: throw events at it, with odds that depend on where the craft is, and let the player save the mission with an emergency pulse paid from the reserve.

## Files you own
- `autoload/EventDirector.gd`
- `scripts/events/**` (new; for example `ThreatModel.gd`, `EmergencyOverlay.gd`, one file per event kind)
- `scenes/events/EmergencyOverlay.tscn` (new)
- `data/event_types.json`
- In `data/missions.json`: only the `hazard_zones` and `hazard_rates` keys of each mission
- `scenes/development/T07_demo.tscn`, `tests/test_events.gd` (new)
- `docs/ai_usage/T07.md`, `docs/references/T07.md`, `tasks/notes/T07.md` (new)

## What you provide
Nothing that other modules call. `EventDirector` listens to `FlightSimulation` and acts on it through its public functions. It adds its own overlay to the scene tree when needed, so the execution console (T08) does not need to know about it.

## What you consume
| From | What |
|---|---|
| T03 | signals `flight_started`, `simulation_step`; fields `craft_state`, `vehicle_state`, `trajectory`, `simulation_time_seconds`; functions `add_threat`, `remove_threat`, `raise_alert`, `apply_emergency_pulse`, `log_event`, `end_flight`, `set_time_scale` |
| T01 | `Kepler.propagate` for a threat's own motion; `OrbitModel.build_trajectory_from_state` to preview an emergency pulse |
| T02 | `RocketModel.available_delta_v_meters_per_second` for the stages that can still fire |
| T05 (same wave) | `OrbitView`, display functions only: `configure`, `show_trajectory`, `show_craft`, `show_threats`, `world_to_screen`. Until T05 is merged it draws a plain body, path and dots. |
| Integrator | `GameState.mission`, `GameState.accepted_side_quests()`, `GameState.random_seed` |

## Requirements
Design reference: `context/plan_draft.md`, section "Random events during EXECUTION" (all of it). Rules: `CONTRACTS.md`, "Flight time" and "Event log".

1. **Rolling.** On every `simulation_step`, for each event type, take the rate for the craft's current altitude from the mission's `hazard_rates` and roll with probability `1 − e^(−events_per_hour × step_seconds / 3600)`. Multiply the rate by the event's `inside_zone_multiplier` inside a matching hazard zone, and by a side quest's `related_multiplier` when an accepted side quest lists the event. No event before its `earliest_time_seconds`.
2. **Repeatable.** One `RandomNumberGenerator` seeded from `GameState.random_seed`. The same seed and plan give the same events.
3. **Threat events** (satellite conjunction, debris, asteroid): create a `Threat` on a path that passes close to the craft some minutes ahead, and hand it to `FlightSimulation.add_threat`. Compute its closest-approach time and miss distance by stepping both objects forward.
4. **Detection.** A threat becomes an alert when T03's radar reveals it (`Threat.is_revealed`). With no radar, alert a few seconds before the closest approach. This is the payoff for buying a good radar.
5. **Alert.** Call `FlightSimulation.raise_alert` (it pauses time) and open the emergency overlay.
6. **Emergency overlay.** An `OrbitView` showing the craft's path, the threat's path, the closest-approach point and the miss distance. The player picks a stage that can still fire and sets an arrow at the craft's position: direction only for a solid motor, direction and size for a liquid engine. The new path and miss distance update while dragging. EXECUTE calls `FlightSimulation.apply_emergency_pulse` with a pulse whose `fires_immediately` is set. IGNORE closes the overlay.
7. **Outcome** at closest approach: beyond the safe distance → "THREAT AVOIDED"; otherwise a collision: destroy the craft (`end_flight` with `COLLISION`) for a large object, or mark a random instrument as not working for small debris.
8. **Fault and environment events:** engine malfunction (lower `specific_impulse_factor`, or set `has_failed`), propellant leak (drain a stage over time), sensor failure (mark one instrument not working), solar flare (raise sensor noise for a while through a function you agree with T03 in your notes).
9. **Log** every event with `FlightSimulation.log_event`, with a one-sentence explanation the final screen can show (for example how much warning the radar gave).
10. **No score effect.** Events give no points and take none directly.
11. **Data.** Fill `data/event_types.json` with the seven event types of the design, and `hazard_zones` and `hazard_rates` for every mission. Realism is expressed through the rates: conjunctions and debris likely in low orbit, asteroids very unlikely. Mark the rates as placeholders unless you cite a source for them.

## Out of scope
Telemetry, the radar panel and the alarm lamp (T03 and T08). Scoring (T04).

## How to check your work
In `tests/test_events.gd`:

| Check | Expected |
|---|---|
| Same seed twice | the same events at the same times |
| A rate of 0 | no events in 10 000 steps |
| A rate of 0.2 per hour over many simulated hours | event count close to 0.2 × hours |
| A threat aimed at the craft | computed miss distance below its collision radius |
| The same threat after a large pulse | miss distance grows |

- `scenes/development/T07_demo.tscn`: starts a flight and forces one conjunction after a few seconds, so a human can try the overlay.

## Definition of done
- No `STUB(T07)` remains.
- `tools/check_project.sh` passes, and a human has avoided a threat in the demo scene.
- The three hand-back files exist.
