# T04 · Missions, scoring and the final screen

**Lane D · Wave 1 · Branch `task/T04-missions-scoring-final-screen` · Needs: the skeleton on `main`. Works on the stub of T01.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Give the game its beginning and its end: the screen where the player chooses a mission, the rules that turn a flight into a score, and the screen that explains that score.

## Files you own
- `data/missions.json`, `data/bodies.json`
- `scripts/mission/**` (`MissionSelect.gd`, `Scoring.gd`, `FinalScreen.gd`, and new files)
- `scenes/MissionSelect.tscn`, `scenes/FinalScreen.tscn`
- `assets/placeholders/portraits/*` (new)
- `tests/test_scoring.gd` (new)
- `docs/ai_usage/T04.md`, `docs/references/T04.md`, `tasks/notes/T04.md` (new)

## What you provide
- `Scoring.compute_score`, `Scoring.budget_points`, `Scoring.band_name_for_points`.
- A mission select screen that ends by calling `GameState.select_mission(...)` and then `GameState.go_to_scene(GameState.CONSOLE_SCENE_PATH)`.
- A final screen that reads `GameState.score` and `GameState.flight_result`.
- Mission and body data in the format of `CONTRACTS.md`, section 7.

## What you consume
| From | What | Until the real one is merged |
|---|---|---|
| T01 | `Kepler.fraction_of_period_inside_band` (already inside `FlightResult.science_coverage_fraction`) | 1 inside the band, else 0 |
| Integrator | `GameState`, `GameData`, `ScreenLayout` | real |

## Requirements
Design reference: `context/plan_draft.md`, sections "Game flow" and "Scoring"; team rules in `context/Notes/Scoring Missions.md`.

1. **Mission select**, in this order: pick a mission card; pick one science mission; accept side quests (optional); "Accept mission".
   - The briefing shows the target orbit and tolerance, duration, budget and the hazards of the region.
   - Each science mission shows its zone and which instruments fit it.
   - Each side quest shows the budget it adds, the points for success, the penalty for failure and the events it makes more likely.
2. **Scoring**, exactly as the table in `plan_draft.md`, "Scoring":
   - Mission 50: orbit achieved 20, altitude accuracy 15, orbit shape 10, vehicle health 5.
   - Budget 30: within budget 25, margin 5; over budget, the 25 becomes 25 minus the percent over, with a floor of −25.
   - Science 20: instrument fit 8, coverage 8, data returned 4.
   - Side quests: +20 for each success; failure penalty 5, 15 or 30 for one, two or three failures. A failed side quest's grant is taken back before the budget part is computed.
   - A launch failure scores 0 with `is_launch_failure` set.
   - Every `ScoreLine` has a one-sentence explanation that uses the player's own numbers.
3. **`budget_points(cost, budget)`** returns the budget part alone; the design screen shows it as the projected penalty.
4. **Bands** as in `band_name_for_points`.
5. **Final screen:** the band with its portrait, the score table, and the event log from `flight_result.event_log`. A launch failure shows "Rocket didn't launch successfully" and score 0. One button returns to the main menu.
6. **Data:** two or three placeholder missions with different targets, budgets and science missions, to prove that a mission is only a JSON entry. Mark them as placeholders in their text; the team decides the real list later.
7. **Portraits:** simple generated placeholder images, one per band. Use no likeness of a real person and no third-party characters.
8. Use the 640×400 canvas and the colours in `ScreenLayout`.

## Out of scope
The planning and execution screens. Event rates in `missions.json` (T07 fills `hazard_zones` and `hazard_rates` in wave 2; keep the seed values valid).

## How to check your work
In `tests/test_scoring.gd`, build `FlightResult` objects by hand:

| Check | Expected |
|---|---|
| Launch failure | 0 points, `is_launch_failure` true |
| Perfect flight, 10% under budget, no side quests | 100 points, band "Perfect" |
| Same flight, exactly on budget | 95 points |
| Same flight, 10% over budget | budget part 15 |
| Same flight, 60% over budget | budget part −25 |
| Altitude error equal to half the tolerance | altitude accuracy 7.5 |
| One side quest succeeded | +20 |
| Two side quests failed | −15 |
| Sum of all `ScoreLine.points` | equals `total_points` |

Open `scenes/MissionSelect.tscn` and `scenes/FinalScreen.tscn` in the editor and have a human look at them.

## Definition of done
- No `STUB(T04)` remains.
- `tools/check_project.sh` ends with "All checks passed."
- The three hand-back files exist.
