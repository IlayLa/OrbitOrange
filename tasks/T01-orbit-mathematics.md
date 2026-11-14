# T01 · Orbit mathematics

**Lane A · Wave 1 · Branch `task/T01-orbit-mathematics` · Needs: the skeleton on `main`, nothing else.**

Read [README.md](README.md) and [CONTRACTS.md](CONTRACTS.md) first.

## Goal
Replace the circular-orbit stubs with real two-body mathematics, so that any launch and any list of burns gives the correct flight path: closed orbits, sub-orbital arcs that hit the ground, and escapes.

## Files you own
- `scripts/orbit/Kepler.gd`
- `scripts/orbit/OrbitModel.gd`
- `tests/test_kepler.gd`, `tests/test_orbit_model.gd` (new)
- `docs/ai_usage/T01.md`, `docs/references/T01.md`, `tasks/notes/T01.md` (new)

## What you provide
Every function in the two script files, with the signatures and comments already there. Nothing else in the project computes an orbit.

## What you consume
Only the shared types in `scripts/core/types/` and a body Dictionary from `data/bodies.json` (keys in `CONTRACTS.md`, section 7).

## Requirements
Design reference: `context/plan_draft.md`, sections "Keplerian dynamics", "State representation and special cases", "Leaving Earth orbit", "Launch: simple ballistic physics" and "Pulses".

1. **`elements_from_state`** for every case in `CONTRACTS.md`, "Orbit conventions": non-circular, circular (eccentricity below 10⁻¹¹), clockwise, and open orbits. Fill every field of `OrbitElements`.
2. **`state_from_elements`** as its exact inverse.
3. **`propagate`** by solving Kepler's equation (Newton's method) for closed orbits and the hyperbolic form for open ones. It must accept negative durations and durations of many periods.
4. **`launch_state`**: position on the surface at the launch-site angle; velocity of the given burnout speed, `launch_angle_radians` above the local horizontal, counter-clockwise.
5. **`seconds_until_polar_angle`**: exact for any closed orbit; `INF` when the craft hits the surface (radius below body radius plus atmosphere) or escapes before reaching the angle.
6. **`fraction_of_period_inside_band`** using the formula in `plan_draft.md`, "Scoring", "Coverage for an altitude-band zone".
7. **`OrbitModel.build_trajectory`**: one segment per burn, following the pulse rule in `CONTRACTS.md`. Set each segment's end time and end reason, and the trajectory status:
   - `IMPACT` when the final path's periapsis is inside the atmosphere,
   - `ESCAPE` when the final path is open,
   - `UNREACHABLE_PULSE` (with the pulse index) when a burn's angle is never reached,
   - otherwise `REACHES_ORBIT`.
8. **`build_trajectory_from_state`** for emergency previews: the first burn may have `fires_immediately` set.
9. **`sample_segment_points`**: from the segment's start to its end; a never-ending closed segment gives one full revolution; an open or impacting segment stops at the atmosphere or at 20 body radii.
10. All mathematics in 64-bit `float`. No `Vector2`.

## Out of scope
Rocket masses and the rocket equation (T02). Drawing (T05). Gravity of other bodies.

## How to check your work
Write the tests below in your two test files. Use Earth from `GameData.body("earth")`.

| Check | Expected |
|---|---|
| Circular orbit at 400 km altitude | speed ≈ 7672.6 m/s, period ≈ 5545 s |
| Hohmann transfer from 400 km to 800 km | pulses ≈ 109.3 m/s and ≈ 107.7 m/s |
| `propagate` over one full period | returns to the starting state |
| Along any propagated orbit | specific energy and angular momentum stay constant |
| `elements_from_state` then `state_from_elements` | returns the input, for an ellipse, a circle, a clockwise orbit and an open orbit |
| A state with speed above escape speed | `is_open` is true |
| Horizontal launch at 7000 m/s from the surface | trajectory status `IMPACT` |
| Launch plus a prograde pulse at apoapsis that circularises | status `REACHES_ORBIT`, eccentricity near 0 |
| A pulse placed at an angle behind an impact point | status `UNREACHABLE_PULSE` |

## Definition of done
- No `STUB(T01)` remains.
- `tools/check_project.sh` ends with "All checks passed." (the skeleton's tests still pass).
- The three hand-back files exist. `docs/references/T01.md` cites the GMAT Mathematical Specifications (https://ntrs.nasa.gov/citations/20080031744) and any other source used for formulas.
