# T02 · Rocket model and parts catalogue

**Lane B · Wave 1 · Branch `task/T02-rocket-model-and-parts` · Needs: the skeleton on `main`, nothing else.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Make the rocket real as numbers: a catalogue of parts with sourced data, and the mass bookkeeping that says how much velocity change every stage and every pulse can deliver.

## Files you own
- `scripts/rocket/RocketModel.gd`
- `data/parts.json`
- `assets/placeholders/parts/*.png` (generated; see requirement 8)
- `tests/test_rocket_model.gd` (new)
- `docs/ai_usage/T02.md`, `docs/references/T02.md`, `tasks/notes/T02.md` (new)

## What you provide
Every function in `RocketModel.gd`, with the signatures and comments already there, and the parts catalogue in the format of `CONTRACTS.md`, section 7.

## What you consume
`GameData.part(part_id)` for part data, and the shared types `RocketDesign`, `Stage`, `MissionPlan`, `Pulse`, `VehicleState`, `BurnOutcome`, `PlanSummary`.

## Requirements
Design reference: `context/plan_draft.md`, sections "Rocket design", "Why ΔV values change while planning (mass bookkeeping)" and "Launch: simple ballistic physics". Rules: `CONTRACTS.md`, "Rocket rules".

1. **`total_mass_kilograms`** and **`create_vehicle_state`** are already real; review them.
2. **`available_delta_v_meters_per_second`**: the rocket equation for the stage's remaining propellant, with every lower stage dropped first. Use the stage's `specific_impulse_factor`. Zero for a failed, dropped or empty stage.
3. **`apply_burn`**: change the `VehicleState` (drop lower stages, burn propellant, drop the stage when empty) and fill every field of `BurnOutcome`. Burn duration is propellant used divided by mass flow, with mass flow = thrust ÷ (specific impulse × standard gravity).
4. **`summarize_plan`**: on a fresh vehicle state, fire the launch stages completely, subtract the launch loss to get the burnout speed (never below zero), then fire each pulse in order. Fill every field of `PlanSummary`, including the reserve after the whole plan.
5. **`validate_design`**: one clear sentence per problem. Add a warning (not a blocker elsewhere) when the first launch stage's thrust is less than the rocket's weight on the pad.
6. **The catalogue**, about 25 parts in three tiers per kind. Design reference: the table "POC catalogue" in `plan_draft.md`.
   - engines: solid motors and liquid engines
   - tanks: three materials, `regulated` and `blowdown`
   - telemetry: proximity radar, altimeter, attitude sensor, fuel gauge, temperature sensor, onboard computer
   - science: camera, magnetometer, atmosphere probe, imaging radar
7. **Sources.** Every number comes from a public source named in the part's `source` and listed in `docs/references/T02.md`. Prefer NASA sources (engine fact sheets, CubeSat 101); the challenge is judged on real use of NASA data. Set `is_approximate` to true for anything rounded or estimated, and say so honestly. Never invent a number and present it as sourced.
8. **Balance.** With the seed mission's budget, at least one design must reach a 400 km orbit and at least one obvious cheap design must fail. State both example designs in `tasks/notes/T02.md`.
9. After editing the catalogue, run `godot --headless --script tools/generate_placeholders.gd` and then `godot --headless --import`, so that every `icon_path` exists.

## Out of scope
Orbits (T01). The design screen (T06). Power and data budgets (deferred; store the numbers only).

## How to check your work
In `tests/test_rocket_model.gd`:

| Check | Expected |
|---|---|
| 100 kg of propellant, specific impulse 300 s, from 3000 kg | ≈ 99.7 m/s |
| The same from 1000 kg | ≈ 310.0 m/s |
| `propellant_needed_for_delta_v` | inverse of the rocket equation |
| A two-stage rocket | firing stage 2 marks stage 1 as dropped and lowers the mass |
| A solid motor | burns everything whatever is requested |
| A liquid engine asked for more than it has | delivers what it has; `is_pulse_affordable` false |
| Every part in the catalogue | has every required key for its category |

Use `GameData.register_part` to add test parts with round numbers.

## Definition of done
- No `STUB(T02)` remains.
- `tools/check_project.sh` ends with "All checks passed."
- The three hand-back files exist, and every part's source is in `docs/references/T02.md`.
