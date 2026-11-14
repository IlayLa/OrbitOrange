# T06 · Rocket design and the planning overview

**Lane B · Wave 2 · Branch `task/T06-rocket-design-and-planning-overview` · Needs: T02 and T04 merged into `main`.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Build the PLANNING half of the console: the overview with its two monitors, the screen where the player assembles the rocket from parts, the three stat chips that show the cost of every choice, and the Launch button.

## Files you own
- `scripts/design/**` (`PlanningConsole.gd`, `RocketDesign.gd`, and new files such as `PartCard.gd`, `PartDetailsPopup.gd`, `StatChips.gd`, `ZoomTransition.gd`)
- `scenes/PlanningConsole.tscn`, `scenes/planning/RocketDesign.tscn`
- `scenes/development/T06_demo.tscn` (new)
- `assets/placeholders/vehicle/*` (new)
- `docs/ai_usage/T06.md`, `docs/references/T06.md`, `tasks/notes/T06.md` (new)

## What you provide
- **`scenes/PlanningConsole.tscn`**: a full-screen (640×400) `Control` that the console shell places as its left half. It owns the overview, the zoom into the two detail screens, the stat chips on all three, the back button and the Launch button.
- **`scenes/planning/RocketDesign.tscn`**: the rocket design screen.

## What you consume
| From | What |
|---|---|
| T02 | `GameData.parts_in_category`, `GameData.part`; `GameState.summary` (cost, masses, total delta-v, warnings) |
| T04 | `Scoring.budget_points(cost, budget)` for the projected budget penalty; `GameState.science_mission()` for mission-fit stars |
| T05 (same wave) | `scenes/planning/OrbitPlanning.tscn` as the zoomed orbit screen, and `OrbitView` for the overview monitor. Until T05 is merged both are minimal stubs with the same interface. |
| Integrator | `GameState.design`, `GameState.notify_design_changed()`, `GameState.request_launch()`, `ScreenLayout` |

Change `GameState.design`, call `GameState.notify_design_changed()`, and redraw from `GameState.summary` when `derived_changed` arrives. You never compute a mass or a delta-v yourself.

## Requirements
Design reference: `context/plan_draft.md`, sections "PLANNING half", "Zoom LEFT: Rocket build" and "Rocket design". Mock-ups: `design/planning_screen.png`, `design/construction_screen.png`. Layout: the `OVERVIEW_` and `ROCKET_DESIGN_` rectangles in `ScreenLayout`.

1. **Overview.** Background mock-up. A small rocket preview in `OVERVIEW_ROCKET_MONITOR_SCREEN`. An `OrbitView` in `OVERVIEW_ORBIT_MONITOR_SCREEN` showing `GameState.trajectory`. Clicking a monitor zooms into its detail screen.
2. **Zoom.** An animated move from the monitor to the full-screen detail scene and back. While zoomed, show a back button in `ScreenLayout.BACK_BUTTON_RECT`; Esc also goes back.
3. **Stat chips** on all three planning screens: cost against budget, total delta-v, and weight (total and empty). In the overview they sit in `OVERVIEW_STAT_CHIP_SCREENS`; on the orbit screen in `ORBIT_PLANNING_STAT_CHIP_SCREENS`; on the rocket design screen wherever fits the mock-up. The weight chip has no limit. The cost chip turns red over budget and shows the projected penalty from `Scoring.budget_points`.
4. **Launch button** in `OVERVIEW_TOP_BEZEL`. Disabled, with the reason shown, only when `summary.warnings` reports that the rocket cannot fly. Going over budget does not disable it. Pressing it calls `GameState.request_launch()`.
5. **Rocket design screen.**
   - Four category tabs in `ROCKET_DESIGN_CATEGORY_TABS`, labelled ENG, MAT, TEL, SCI for the categories `engine`, `tank`, `telemetry`, `science`.
   - Part cards in `ROCKET_DESIGN_PART_LIST` (scrolling): icon, name, cost, and the one number that matters most for that category.
   - Clicking an engine card adds a stage. Clicking a tank card attaches it to the selected liquid stage. Clicking a telemetry or science card adds it to the payload.
   - The preview in `ROCKET_DESIGN_PREVIEW_SCREEN` shows the stack, bottom stage at the bottom, payload on top. Clicking an installed part removes it.
6. **Details popup** on hovering a card: every stat with its unit, engine type, mission-fit stars for the chosen science mission, the trade-off sentence and the source.
7. **Removing a stage** must also remove its id from `GameState.plan.launch_stage_ids` and delete the pulses that use it, then call `notify_plan_changed()`.
8. Leave `ScreenLayout.CONSOLE_SWITCH_RECT` empty on every screen.

## Out of scope
Anything inside the orbit planning screen (T05). The EXECUTION half (T08).

## How to check your work
- `scenes/development/T06_demo.tscn`: selects the first mission and shows `PlanningConsole.tscn` alone.
- A human opens the demo and checks: building an engine plus a tank enables Launch; adding parts changes all three chips; going over budget turns the cost chip red and Launch stays enabled; both zooms work and return.
- `tools/check_project.sh` passes.

## Definition of done
- No `STUB(T06)` remains.
- The demo scene runs and a human has confirmed the behaviours above.
- The three hand-back files exist.
