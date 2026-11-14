# T05 · Orbit planning screen

**Lane A · Wave 2 · Branch `task/T05-orbit-planning-screen` · Needs: T01 and T02 merged into `main`.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Build the screen where the player plans the flight: set the launch, place pulses on the path, and see at once how each change reshapes the orbit. This is the centre of the game.

## Files you own
- `scripts/orbit/OrbitView.gd`, `scripts/orbit/OrbitPlanning.gd`
- `scripts/orbit/planning/**` (new; for example `PathRenderer.gd`, `PulseHandle.gd`, `EngineList.gd`, `LaunchControls.gd`)
- `scenes/planning/OrbitPlanning.tscn`
- `scenes/development/T05_demo.tscn` (new)
- `assets/placeholders/orbit/*` (new)
- `docs/ai_usage/T05.md`, `docs/references/T05.md`, `tasks/notes/T05.md` (new)

## What you provide
- **`OrbitView`**: the display widget used by three tasks. Keep its seven public functions exactly as they are (`CONTRACTS.md`, section 5). It must work at any size and never change game state. You may add functions; list them in your notes.
- **`scenes/planning/OrbitPlanning.tscn`**: a full-screen (640×400) `Control`. T06 shows it when the player zooms into the orbit monitor.

## What you consume
| From | What |
|---|---|
| T01 | `OrbitModel.sample_segment_points`, `sample_full_orbit_points`, `Kepler.elements_from_state`, `Kepler.seconds_until_polar_angle`, `Kepler.seconds_until_impact` |
| T02 | `GameState.summary` (a `PlanSummary`): delta-v left per stage, which pulses are affordable |
| Integrator | `GameState.plan`, `GameState.design`, `GameState.trajectory`, `GameState.notify_plan_changed()`, `ScreenLayout` |
| T06 (same wave) | T06 draws the three stat chips and the back button over your screen. Leave `ScreenLayout.ORBIT_PLANNING_STAT_CHIP_SCREENS`, `BACK_BUTTON_RECT` and `CONSOLE_SWITCH_RECT` empty. |

Three orbit points you need (from T01, now in `CONTRACTS.md`):
- **Clockwise orbits.** ω and ν are measured along the motion. With `s = +1` counter-clockwise and `s = −1` clockwise, the craft's polar angle is `s·(ω + ν)`, the periapsis direction is `s·ω` and the apoapsis direction is `s·ω + π`. Use this to place the apoapsis and periapsis markers and the readouts.
- **A pulse at the current angle fires at once.** A pulse whose polar angle is within 10⁻⁹ rad of the craft's current direction fires immediately, so two pulses placed at one point fire together.
- **`Kepler.seconds_until_polar_angle` cannot see the ground.** It returns INF only for open orbits and radial paths. To know whether a clicked point is reached before an impact, compare it with `Kepler.seconds_until_impact`, or read `trajectory.status` and `first_unreachable_pulse_index`, which `OrbitModel.build_trajectory` already sets that way.

You never compute an orbit or a mass yourself. Change `GameState.plan`, call `GameState.notify_plan_changed()`, and redraw from `GameState.trajectory` and `GameState.summary` when `derived_changed` arrives.

## Requirements
Design reference: `context/plan_draft.md`, sections "Zoom RIGHT: Orbit planning", "Orbit / pulse planning" (all of it) and "Leaving Earth orbit". Mock-up: `design/orbit_screen.png`. Layout: the `ORBIT_PLANNING_` rectangles in `ScreenLayout`.

1. **Display.** Background mock-up; the orbit view in `ORBIT_PLANNING_VIEW_SCREEN`; the engine list in `ORBIT_PLANNING_ENGINE_LIST`.
2. **`OrbitView` drawing:** the body, labelled altitude rings from the mission's `display.altitude_ring_kilometers`, the launch point, science zones and hazard zones from the mission (hazards hatched red), each trajectory segment, the craft, and revealed threats. Use the display mapping in `CONTRACTS.md`.
3. **Path colours.** Each segment in the colour of the stage that created it; the final orbit drawn brightest. A trajectory with status `IMPACT` is drawn red with the message "WILL NOT REACH ORBIT"; status `ESCAPE` is drawn red with "YOU ARE LEAVING EARTH ORBIT".
4. **Engine list.** One row per stage in firing order: name, solid or liquid, delta-v left (from `summary.delta_v_remaining_by_stage`), and a tick box "fires at launch" that edits `plan.launch_stage_ids`. A row turns red when a pulse on it is not affordable.
5. **Launch controls.** A slider for `plan.launch_angle_radians`, from horizontal to just short of vertical.
6. **Placing pulses.** Select a stage in the list, then click on the path: the click's direction from the body (`screen_to_polar_angle_radians`) becomes the pulse's `polar_angle_radians`.
   - Solid stage: at most one pulse. The player sets the direction only.
   - Liquid stage: any number of pulses. The player sets direction and size (drag the arrow, or a slider).
   - A stage's pulses must come after the previous stage's pulses in `plan.pulses`.
7. **Editing.** Drag a pulse along the path to move it; drag its arrow to change it; right-click or a button to delete it. A pulse whose index is `trajectory.first_unreachable_pulse_index` is drawn red.
8. **Ghosts.** For the selected pulse only: the full orbit before it drawn faint, and the full orbit after it drawn dashed. While dragging, keep the path from the start of the drag as a faint ghost.
9. **Readouts** over the view: apoapsis and periapsis altitude, period, eccentricity (or "CIRCULAR" below 0.001), and the reserve delta-v.
10. **Speed.** Call `notify_plan_changed()` at most once per frame while dragging.

## Out of scope
Stat chips, the back button, the zoom animation (T06). Emergency pulses (T07 builds its own arrow on top of `OrbitView`). The Moon.

## How to check your work
- `scenes/development/T05_demo.tscn`: selects the first mission, builds a two-stage rocket in code, and shows `OrbitPlanning.tscn`, so the screen runs alone.
- A human opens the demo and checks: a launch that falls back is red; adding a prograde pulse at the top of the arc gives a closed orbit; dragging the pulse changes the orbit live; a very large pulse shows the escape warning.
- `tools/check_project.sh` passes.

## Definition of done
- No `STUB(T05)` remains.
- The demo scene runs and a human has confirmed the four behaviours above.
- The three hand-back files exist.
