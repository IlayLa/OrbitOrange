# OrbitOrange — Initial Godot Template (redesigned to match the team sketch)

> **Names are fixed in `tasks/CONTRACTS.md`.** File names, function signatures and JSON keys there win wherever this document differs. All identifiers use full words with units written out (for example `delta_v_along_velocity_meters_per_second`, `specific_impulse_seconds`).

## Context
The NASA Space Apps 2026 "Space Mission Design Game" asks for mission design with real trade-offs. From `context/Notes/Absolute Truths.md`: **2D, pixel art, Godot (4.7), POC, Keplerian mechanics, control-room look**. The POC mission is a **low Earth orbit** (Tasks.md idea #1). The team wants an editable template with placeholder assets for **telemetry screens, rocket design and Keplerian dynamics**, focused on **mission planning**.

The visual design comes from the team sketch: `context/ScreensDraft.jpeg`.

**Everything mission-specific is data.** Missions, science missions, side quests, hazards, parts and celestial bodies are JSON entries. The entries shipped now are placeholders until the team decides the real lists (Tasks.md #1–3); adding or changing one means editing JSON, not code. Each mission entry sets its own win condition and numbers: target orbit and tolerances, mission duration, budget, launch loss term, scoring weights and hazard rates.

## Game flow
`MainMenu → MissionSelect → Console (PLANNING ⇄ EXECUTION) → FinalScreen`

**Mission select (`scenes/MissionSelect.tscn`)** comes first, so the objective drives the engineering choices:
1. Pick a mission card (from `data/missions.json`). The briefing shows the target orbit and tolerance, duration, budget and the hazards of that region.
2. Pick one science mission. It shows which SCI instruments fit it (stars) and where it must be performed (science zone).
3. Accept side quests (optional). Each card shows the budget it adds, the points for success, the penalty for failure and the events it makes more likely.
4. "Accept mission" opens the console. The choices fill the objective list and are fixed for the run.

## Visual design (from the sketch)
The game is **one control-room console with two halves**: **PLANNING ◀ | ▶ EXECUTION**. The player switches with the arrow tabs at the top (slide transition). On a 640×400 pixel viewport (exactly 5× the 128×80 mock-ups in `design/`) each half fills the screen. EXECUTION stays locked until "Launch".

### PLANNING half (`scenes/PlanningConsole.tscn`): overview + two zoom views
**Overview** (top-left of the sketch): two monitors, the **rocket monitor** on the left and the **orbit monitor** on the right, with compact `$` `ΔV` `W` chips on top. `W` is the rocket's weight (mass in kg), shown as total and empty (dry). It is a readout only and has no upper limit. Each monitor has a **🔍 zoom button** (and click-to-zoom). Zooming is an animated camera/scale move into that monitor. Pressing "◀ back" or Esc zooms out. Stages and part cards are **not** shown in the overview.

**Zoom LEFT: Rocket build** (bottom-left of the sketch, `scenes/RocketDesign.tscn`)
```
┌──────────────┬──────────────────────────┐
│              │ [ENG][MAT][TEL][SCI]     │
│   ROCKET     │ ┌────┐ ┌────┐ ┌────┐     │
│   PREVIEW    │ │icon│ │icon│ │icon│     │   hover a card →
│  (stack)     │ │$ ΔV│ │$ ΔV│ │$ W │     │   details popup
│              │ └────┘ └────┘ └────┘     │
└──────────────┴──────────────────────────┘
```
- Tabs ENG / MAT / TEL / SCI show **part cards** (icon, name, `$`, `ΔV` or `W`). Click a card to add it to the rocket (engines and tanks stack as stages; TEL/SCI go into the payload).
- **Hover a card → single-part details popup:** full stats (cost, mass, Isp/thrust or sensor quality, power, data), engine type (solid/liquid), mission-fit stars, trade-off text, NASA source.
- The rocket preview updates live. Click an installed part to remove it.

**Zoom RIGHT: Orbit planning** (bottom-center of the sketch, `scripts/orbit/OrbitView.gd`)
```
   [ $ ]   [ ΔV ]   [ W ]
┌──────────────────────────────┐ ┌──────────┐
│  orbit view: Earth, LAUNCH   │ │ ENGINE 1 │
│  POINT, ascent, pulse points │ │ ENGINE 2 │
│  with ΔV arrows, new orbits  │ │  ...     │
└──────────────────────────────┘ └──────────┘
```
- **The engine list appears only in this zoomed view.** It lists the rocket's engines (stages) in firing order, each with its remaining ΔV.
- **Click an engine to plan with it:**
  - **Solid engine → a single point.** Choose one point on the path and the direction. Its ΔV is fixed (the whole motor fires at once).
  - **Liquid engine → multiple points.** Add several points. At each one, set direction and how much ΔV to spend. The sum must stay within that engine's ΔV.
  - All within ΔV limits: the ΔV chip and each engine row go red if over budget.
- The rest is described under "Orbit / pulse planning".

### EXECUTION half (`scenes/ExecutionConsole.tscn`): control room
```
┌────────────┬──────────────────────────────────────────────┐
│ [ time ]   │        [ ALARM ]                              │
│ [ ΔV ]     │  [TEMP]                       ┌──────────┐    │
│ ┌────────┐ │          ┌──────────┐         │ Angles   │    │
│ │objective│ │  radar → │  RADAR   │         │ θ  γ     │    │
│ │ list    │ │          └──────────┘         └──────────┘    │
│ └────────┘ │  [Altitude]  [Fuel]           [Acc g]         │
└────────────┴──────────────────────────────────────────────┘
```
Left column: mission time, ΔV remaining, objective list. Instrument wall: **ALARM** (flashing warnings), **TEMP** (engine/tank temperature), **RADAR** (center), **Angles θ γ** (attitude and flight-path angle), **Altitude**, **Fuel**, **Acc** (accelerometer, in g). The fake self-destruct button sits in a corner.

## Project layout
```
project.godot                 Godot 4.7, 640x400, stretch canvas_items, integer scale, nearest filter, GL Compatibility
autoload/GameState.gd         budget, rocket (stages+parts+derived), mission plan, results, signals
autoload/GameData.gd          loads the JSON files in data/
scripts/orbit/Kepler.gd       2D two-body math (static class)
data/parts.json               ENG / MAT / TEL / SCI catalogue (NASA-sourced, approx flags)
data/missions.json            per mission: target orbit + tolerances, duration, budget, launch site, loss term,
                              science missions, side quests, hazard zones, hazard rates, scoring weights
data/bodies.json              celestial bodies (Earth now; Moon later): mu, radius, atmosphere, sprite
data/event_types.json              random event definitions (see Random events)
scenes/MainMenu.tscn          -> MissionSelect
scenes/MissionSelect.tscn     mission card, science mission, side quests -> Console
scenes/Console.tscn           holds both halves, PLANNING/EXECUTION arrow tabs, slide transition
scenes/PlanningConsole.tscn   rocket preview + parts column + stat chips + orbit view + stage list
scenes/RocketDesign.tscn      rocket preview monitor (separate scene, embedded)
scenes/ExecutionConsole.tscn  instrument wall
scenes/FinalScreen.tscn       score + task explanations + Amit portrait
scripts/rocket/RocketModel.gd mass chain, ΔV and cost (logic only, no screen)
scripts/design/{RocketDesign,PartCard,PartDetailsPopup,StatChips}.gd
scripts/mission/MissionSelect.gd  builds the briefing and choices from missions.json
scripts/ui/ZoomMonitor.gd     overview <-> zoom animation for a monitor
scripts/orbit/EngineList.gd   engine rows, select engine -> pulse placement mode
scripts/orbit/{OrbitModel,OrbitView,Pulse,PathRenderer}.gd
scripts/execution/{EventDirector,EmergencyManeuver,ThreatModel}.gd
scripts/telemetry/{TelemetryFeed,TelemetryPanel}.gd + {Radar,Angles,Altitude,Fuel,Acc,Temp,Alarm}Panel.gd
tools/generate_placeholders.py   PIL placeholders (replace PNGs keeping names)
tools/check_project.sh        headless Godot checks: import, script check, scene smoke run, physics tests
tests/test_kepler.gd          physics tests against known values (see Verification)
docs/AI_USAGE.md              log of AI use (see AI use and references)
docs/REFERENCES.md            every external resource, with licence
assets/placeholders/{console,parts,vehicle,orbit,telemetry,portraits}/*.png
README.md
```

## Rocket design (Planning: left monitor + parts column + stage list)
**Rocket = stages.** Each stage = engine (ENG) + tank/structure material (MAT). Engines left after the ascent perform the pulses (solid = one pulse, liquid = several). The top stage carries the payload: TEL and SCI instruments.

**ΔV:** Tsiolkovsky per engine, in firing order, with spent stages jettisoned (`RocketModel.summarize_plan`). The `ΔV` chip shows total ΔV. Launch and orbit use the same engines (see Orbit / pulse planning).

**Data sources** (`context/NASA Space Apps Challenge description.html` → NASA Data & Resources). Part numbers start as public figures flagged `"is_approximate": true`, each with a `source` field. Yasha (Tasks.md #4) verifies each against its source and clears the flag:
| Resource | Used for |
|---|---|
| CubeSat 101 | payload bus sizes (1U/3U/6U), subsystems, power/data figures for TEL/SCI parts |
| Design & Develop Science Missions | launch / space / ground / user segments → stage parts vs. payload vs. comms vs. science value |
| GMAT | propulsion fields (`Isp`, `FuelMass`, `DryMass`, tank `Pressure`/`Temperature`), pulse = `ImpulsiveBurn` |
| Mission Design Lab / CMLs | green/amber/red margins on the $ and ΔV chips |
| Webb "Build it yourself", Mission Viz | UX/visual references for part picking and the rocket preview |

**Part schema** (one entry, all fields GMAT-compatible where possible):
```json
{ "id": "engine_rl10", "category": "engine", "name": "RL10-class upper-stage engine",
  "cost_million_usd": 10, "dry_mass_kilograms": 300,
  "stats": { "engine_type": "liquid", "specific_impulse_seconds": 465, "thrust_kilonewtons": 110 },
  "mission_fit": { "earth_imaging": 3 }, "tradeoff": "Very efficient, expensive; ideal upper stage.",
  "source": "public spec; GMAT ChemicalThruster fields", "is_approximate": true }
```
A liquid engine's propellant lives in its tank (a `tank` part with `propellant_capacity_kilograms`); a solid motor carries its own `propellant_kilograms`. The four categories are `engine`, `tank`, `telemetry` and `science`; the screen labels them ENG / MAT / TEL / SCI.

**POC catalogue (3 tiers each, approximate):**
| Tab | Parts | Key stats | How it complements the mission |
|---|---|---|---|
| ENG, solid | small solid kick motor, Star-class solid, large solid booster | Isp, propellant, mass, cost (cheap) | Cheap launch muscle. In orbit: **one fixed-ΔV pulse, direction only** |
| ENG, liquid | cold-gas thruster, Rutherford-class (Isp ~343 s vac), Merlin-class (Isp ~282 s SL / 348 s vac), RL10-class (Isp ~465 s) | Isp, thrust, cost | Upper stage: **pulses with chosen direction + ΔV**. Higher Isp = more ΔV per kg, at higher cost |
| MAT | aluminium tank, Al-Li tank, carbon-composite tank; blow-down vs. regulated pressurization | dry mass, propellant capacity, cost | Lighter tanks = more ΔV. Blow-down is cheaper, but later pulses get weaker (GMAT `PressureModel`) |
| TEL | **proximity/collision radar** (navigation; *not* the SCI imaging radar), altimeter, attitude sensor, fuel gauge, temperature sensor, onboard computer, each in 3 tiers | range, noise, updates per second, resolution, dropout | Decides the quality of each EXECUTION panel. Missing = "NO SENSOR". The accelerometer is built in and needs no part. A better onboard computer reduces glitches during solar flares |
| SCI | camera (Earth imaging), magnetometer (space weather), drag/Langmuir probe (atmosphere), **SAR imaging radar** (Earth-surface science; *not* the TEL proximity radar) | mass, power, data, cost, science value | Each matches a science mission (`mission_fit` 0–3, shown as stars) |

The `$`, `ΔV` and `W` chips plus mission-fit stars update live. **Going over budget is allowed and costs score points** (see Scoring): the `$` chip turns red and shows the projected penalty. "Launch" is disabled (with a tooltip) only when there's no engine. A plan that doesn't reach orbit *can* be launched: it fails (see Launch).

## Orbit / pulse planning (Zoom RIGHT, ★ focus)
**Scene:** Earth, launch point (missions.json), the trajectory, pulse points with ΔV arrows, science zones (altitude bands).

**Display scale (`OrbitView`).** Drawn to true scale, a 400 km orbit sits about 6% of Earth's radius above the surface, which is only a few pixels. The view therefore stretches altitude. A point at true radius `r` and polar angle `θ` is drawn at the same angle and at
```
r_px = R_px + k · (r − R)
```
`R_px` is Earth's drawn radius (the sprite size is a setting, not a constant) and `k` (pixels per km of altitude) is the altitude scale, set per mission. Paths are drawn as polylines of sampled points pushed through this map, never as ellipse primitives, because the stretched curve is not an ellipse. Labelled altitude rings (for example 200 / 400 / 800 km) show the scale to the player. All physics uses true coordinates; only drawing and mouse picking use the map.

**Bodies are data (`data/bodies.json`).** Earth is the only entry now (μ, radius, atmosphere height, sprite). `Kepler` functions take μ as an argument and `OrbitView` draws whatever bodies are listed, so the Moon can be added later as a new entry plus an `OrbitModel` extension for its gravity.

**Planning hazards = broad danger zones.** Planning shows large areas from missions.json (debris belt band, radiation belt, an asteroid-corridor sector), drawn as hatched red regions. They are the same for every rocket; instruments don't affect them. Specific objects inside these zones are revealed only during EXECUTION, at close range by the TEL radar.

### Launch: simple ballistic physics
- In the engine list the player marks which engines fire **at launch** (default: the first one). Their ΔV (Tsiolkovsky, firing in order with jettison) minus a fixed **loss term** (gravity + drag, ~1.5 km/s, tunable in missions.json) gives the burnout speed. The player sets the **launch angle** with a slider.
- The ascent is a **ballistic arc**: launch point + burnout velocity, then free flight under gravity only. In 2D two-body physics a ballistic arc *is* a Kepler conic, so the same `Kepler.propagate` draws it. No extra physics needed.
- A trajectory that starts at the surface always comes back down, unless a pulse raises the periapsis. So, as in the sketch, the player places a **ΔV pulse near the top of the arc** with a remaining engine to circularize.
- **Launch failure:** if the final planned path hits Earth or has periapsis inside the atmosphere (< 100 km), the arc is drawn red and planning shows "WILL NOT REACH ORBIT". If launched anyway, EXECUTION shows the crash and FinalScreen shows a special **"Rocket didn't launch successfully"** result with **score 0**.
- **Launch angle limit:** the slider stops short of straight up. A vertical launch has zero angular momentum, which is a degenerate conic.
- **Ascent readout:** EXECUTION plays the burn of the launch engines before the ballistic arc starts, which gives the accelerometer a real signal: `a(t) = F / m(t)`, with `m(t) = m₀ − ṁ·t` and `ṁ = F / (Isp·g₀)` (the same mass-flow relation as GMAT Math Spec eq. 11.1). This uses the engine's `thrust_kilonewtons`. It is a readout only and does not change the trajectory.

### Pulses (instant ΔV, no continuous burns)
Select an engine in the list:
- **Solid → one point.** Place it and rotate its arrow (direction only). ΔV is fixed: the motor burns all its propellant.
- **Liquid → multiple points.** Each gets direction + ΔV (arrow length or slider). No per-pulse cap. The only limit is the engine's remaining propellant.
- Order: points are processed in time order, and an engine's points must come after the previous engine's last point.
- **Pulses are anchored to a place, not a time.** A pulse stores the direction from Earth's centre at which it fires (the inertial polar angle `θ`) plus how many extra revolutions to wait. Its time is derived from the current path. A full `(x, y)` point would be over-specified: once an earlier pulse changes, the new orbit usually no longer passes through that point, while every closed orbit still crosses every direction `θ` once per revolution. If the path never reaches `θ` (it hits Earth first, or escapes), the pulse turns red and must be re-placed.
- **After an emergency pulse** in EXECUTION, the remaining pulses stay attached to their `θ` on the new orbit and are marked "REVIEW". The player can keep, move or delete them.

### Why ΔV values change while planning (mass bookkeeping)
ΔV from a given amount of propellant depends on how much mass it pushes: `ΔV = Isp · g0 · ln(m_before / m_after)`.
1. At launch the rocket weighs everything: all engines, tanks, propellant and payload.
2. Each pulse burns propellant: `m_burned = m · (1 − e^(−ΔV / (Isp·g0)))`. The rocket is now lighter.
3. When an engine is spent (solid after its single point, liquid when its propellant runs out), its stage (engine + tank dry mass) is **jettisoned**, and the rocket is lighter again.
4. So the *same* propellant in a later engine buys **more** ΔV than it would at launch. Example: 100 kg of propellant at Isp 300 s gives ~100 m/s on a 3,000 kg rocket, but ~310 m/s after it's down to 1,000 kg.

`RocketModel.summarize_plan(design, plan, launch_loss_meters_per_second)` re-runs this chain after every edit. Each engine row shows its current available ΔV, and when an earlier pulse is changed, later rows flash the difference (e.g. "+40 m/s"). A solid engine's fixed ΔV also shifts, depending on how much mass is left when it fires.

### Drawing the path with several pulses (`PathRenderer.gd`)
The plan is a chain of segments: segment *i* is the conic flown between pulse *i* and pulse *i+1*.
- **Flown path:** each segment's arc is drawn solid in the color of the engine that created it, so the colors read like a timeline.
- **Final orbit:** the last segment's full ellipse is drawn bright. It's the result.
- **Ghosts only for the selected or hovered pulse,** to avoid clutter: the full ellipse *before* that pulse is drawn faint (25% alpha, dotted) and the ellipse *after* it bright dashed. Other pulses show only their arrows.
- **While dragging,** a snapshot of the path taken when the drag started stays as a faint ghost. Pulses after the dragged one are re-simulated live on the new path, so the player sees how one change ripples through the rest of the plan.

**Readouts** (overlay): apoapsis, periapsis, period, eccentricity, ΔV left per engine, "inside danger zone" warnings. The plan is stored in `GameState.plan`, a `MissionPlan` with `launch_stage_ids`, `launch_angle_radians` and `pulses`. Each `Pulse` has `stage_id`, `polar_angle_radians`, `extra_revolutions`, `delta_v_along_velocity_meters_per_second` and `delta_v_outward_meters_per_second`. EXECUTION replays it.

## Keplerian dynamics (`scripts/orbit/Kepler.gd` behind `OrbitModel`)
We write our own small 2D two-body solver. JR Orrery (MIT, ~12k lines, 3D/N-body/GPU) is overkill for the POC. `OrbitModel` (`build_trajectory`, `state_at_time`, `sample_segment_points`) keeps it swappable for future Moon/Jupiter missions.
SI units, Earth gravitational parameter 3.986×10¹⁴ m³/s² and radius 6371 km.
- `Kepler` (orbits only): `elements_from_state`, `state_from_elements`, `propagate` (Newton solve of Kepler's equation), `apply_pulse` (instant velocity change), `launch_state`, `seconds_until_polar_angle`, `fraction_of_period_inside_band`, `circular_speed_meters_per_second`, `orbital_period_seconds`, `altitude_meters`, `flight_path_angle_radians`.
- `RocketModel` (masses only): `delta_v_from_rocket_equation`, `propellant_needed_for_delta_v`, `available_delta_v_meters_per_second`, `apply_burn`, `summarize_plan`.

### State representation and special cases (following GMAT)
GMAT derives orbital elements from the Cartesian state `(r, v)` (GMAT Mathematical Specifications, draft, §4.1.2 "Cartesian State to Keplerian Elements"). We do the same: `OrbitModel` stores `(r, v)` after every pulse as the truth, and elements are recomputed from it. In 2D every orbit is GMAT's "equatorial" case (`i = 0`, `Ω = 0`), which leaves two of GMAT's four cases, split at its threshold `e = 10⁻¹¹` (Table 4.3):

| Case | ω | ν |
|---|---|---|
| Non-circular, `e ≥ 10⁻¹¹` (eqs. 4.15–4.17) | angle from the x-axis to the eccentricity vector: `ω = cos⁻¹(e_x / e)`, then `ω = 2π − ω` if `e_y < 0` | angle from the eccentricity vector to the position: `ν = cos⁻¹(e·r / (e r))`, then `ν = 2π − ν` if `r·v < 0` |
| Circular, `e < 10⁻¹¹` (eqs. 4.21–4.23) | `ω = 0` | angle from the x-axis to the position: `ν = cos⁻¹(r_x / r)`, then `ν = 2π − ν` if `r_y < 0` |

Our additions, which are not from GMAT:
- **Clockwise orbits.** GMAT's 3D inclination covers these. In 2D we use the sign of `h = x·v_y − y·v_x` and mirror the angles when it is negative.
- **Display.** Below `e = 10⁻³` the apoapsis and periapsis markers are hidden and the readout says "CIRCULAR", because their position is too sensitive to tiny changes to be useful.
- **Precision.** GDScript `float` is 64-bit, but `Vector2` is 32-bit in standard Godot builds. That is too coarse for metres at orbital radii and makes a 10⁻¹¹ threshold meaningless. `Kepler.gd` does its math in plain floats (`x, y, vx, vy`) and converts to `Vector2` only for drawing.

### Leaving Earth orbit
The orbit is open when the specific energy `ξ = v²/2 − μ/r` is ≥ 0 (that is, `e ≥ 1`). GMAT refuses the exactly parabolic case with an error (§4.1.2); we treat all of `ξ ≥ 0` as one state:
- Planning draws the solved path in red out to the edge of the view, using the conic equation `r = p / (1 + e·cos ν)` with `p = h²/μ`, and shows the warning **"YOU ARE LEAVING EARTH ORBIT"**.
- If launched anyway, EXECUTION flies it (hyperbolic Kepler equation) and the mission ends once the craft leaves the view, scored by the normal rules with no orbit achieved.

## How GMAT is used
GMAT does not run inside Godot. For now it's a reference for data and conventions only:
1. **Part fields mirror GMAT** (`DryMass`, `FuelMass`, `Isp`, tank `Pressure`/`Temperature`/`PressureModel`), so our ΔV/mass math matches GMAT's `DecrementMass`.
2. **Pulses = GMAT `ImpulsiveBurn` in the VNB frame.** In 2D we use V (along velocity) and B (in-plane perpendicular). `Pulse.gd` stores `delta_v_along_velocity_meters_per_second` and `delta_v_outward_meters_per_second`, and the arrow on screen converts to and from them.
3. **Element conversion and its special cases** (circular orbits, open orbits) follow the GMAT Mathematical Specifications §4.1.2; see "State representation and special cases". Source: NASA GSFC draft, https://ntrs.nasa.gov/citations/20080031744.

## Execution instruments (driven by TEL parts)
Sim loop: Kepler propagation, with pulses applied at their points. `TelemetryFeed` degrades the true state per installed instrument (`range_kilometers`, `noise_fraction`, `updates_per_second`, `resolution_level` 0 blip / 1 distance+bearing / 2 shape+relative velocity, `dropout_probability`). Panels only see degraded data. Missing sensor → "NO SENSOR".
- **RADAR (TEL proximity radar):** reveals specific objects (debris pieces, asteroid) inside the planning danger zones as the craft gets close. Cheap = noisy short-range blips. Expensive = object outlines, distance, closing speed, at longer range.
- **Angles θ γ:** θ is the attitude (where the nose points, relative to the local horizontal) and γ is the flight-path angle (where the velocity points, relative to the local horizontal). The craft turns to each pulse direction before firing. Noise and refresh rate scale with the attitude-sensor tier.
- **Altitude, Fuel:** noise and refresh rate scale with the tier.
- **Acc:** built in, no part needed. It shows `F / m` during the launch burn and during pulses, and reads 0 in free flight, so the panel can be collapsed after launch.
- **TEMP:** engine/tank temperature and pressure (GMAT `ChemicalTank` fields).
- **ALARM:** aggregates warnings (hazard proximity, low fuel, over-temperature, structural stress from strong pulses; the structural model is a gameplay abstraction, as no NASA data was found).
- **Left column:** mission time, ΔV remaining, objective list with time/distance to the next objective.

### Time controls
A 400 km orbit takes about 92 minutes, so EXECUTION has explicit time controls next to the mission clock: **pause, 1×, 10×, 100×, 1000×**.
- The sim drops to 1× and pauses on every alert, and drops to 1× shortly before each planned pulse.
- Position comes from the closed-form Kepler solution, so warp adds no error. Threat and collision checks run on fixed sub-steps of simulated time (for example 5 s), so a fast warp cannot jump over a close approach.

## Science data and the data link
A science instrument produces data only while it is working and inside its science zone, at the rate given by its `data` stat. The data counts for the score only once it is delivered to the ground. Delivery goes through one interface, `DataLink.deliver(generated_megabits, state, step_seconds)`, with two implementations:

| Version | When | Behaviour |
|---|---|---|
| **1. Instant link** | first development | Everything generated is delivered at once: `delivered = generated`. No comms part is needed |
| **2. Rate-limited link** | final product | Data waits in onboard storage and is sent only during ground-station contact, at the transmitter's rate |

Version 2, in outline:
- **Parts:** a transmitter (TEL) with a data rate, and storage capacity on the onboard computer. Data produced while storage is full is lost.
- **Ground stations:** listed per mission in `missions.json` as positions on Earth's surface. The craft is in contact while it is above the station's horizon: the angle at Earth's centre between craft and station is less than `cos⁻¹(R / r)`. At 400 km that is about 20° either side, roughly 10 minutes per pass.
- **Per contact:** `delivered = min(stored, rate × contact time)`.
- **Trade-off this creates:** a higher-data instrument needs a faster transmitter, more storage or more stations, each of which costs money and mass.

The score uses `delivered` in both versions, so switching versions changes no scoring code. EXECUTION shows generated and delivered data in the left column.

## Random events during EXECUTION
Execution isn't just watching the plan play out. An `EventDirector` throws random events at the mission, and the player can react with an **emergency pulse** paid from the **reserve ΔV**.

### Event catalogue (`data/event_types.json`, easy to extend)
| Event | What happens | How to save the mission |
|---|---|---|
| **Unknown asteroid** | An asteroid appears on an intercept course, with a time to impact | Pulse to change the orbit so the closest approach is > safe distance |
| **Satellite conjunction** | Predicted collision with another satellite (closest approach distance + time shown) | Small avoidance pulse (prograde/retrograde usually suffices) |
| **Engine malfunction** | One engine: loses part of its ΔV (Isp drop / leak), fails completely, or (solid) won't ignite | Re-plan the remaining pulses with the other engines. Planned pulses on the dead engine turn red |
| **Propellant leak** | One liquid engine's propellant drains over time | Use it now (pulse early) or lose it |
| **Sensor failure** | A TEL panel goes "NO SIGNAL" for the rest of the mission | No pulse needed. The player flies with less information |
| **Solar flare** | Telemetry dropout/noise spikes for a while; a cheap onboard computer may glitch | Wait it out. Better TEL parts, including the onboard computer, reduce the effect |
| **Debris shower** | Several fragments while crossing the planning debris zone | One or more avoidance pulses |

### How it works
- **When:** events are rolled during the flight (seeded RNG so a run can be replayed). Each event type has a rate that depends on where the craft is (see "Hazard rates by region"). The rate rises further inside the planning **danger zones** and with side quests. Each side quest in missions.json lists its **related event types** (e.g. "Debris survey" → debris shower, satellite conjunction). Accepting it raises those events' chance a lot (`related_multiplier`, e.g. ×3) and all other events only slightly (`unrelated_bonus`, e.g. +5%). Each event also has a `weight`, `earliest_time_seconds` and `inside_zone_multiplier` in event_types.json.
- **Detection depends on the instruments:** the warning time before impact scales with the TEL radar's `range_kilometers`. A cheap radar spots the asteroid late (little time, more ΔV needed). With no radar, the first warning is the ALARM a few seconds before impact. This is the payoff of buying good telemetry in Rocket Design.
- **Alert:** ALARM flashes, the sim **slows to 1× and pauses** on the first alert, and an **Emergency Maneuver overlay** opens over the radar monitor. It's a mini orbit view showing the threat's predicted path, the craft's path, the closest-approach point and the miss distance.
- **Reacting:** the player picks an available engine from the reserve. Same rules as planning: **solid = one point, direction only, fixed ΔV; liquid = choose direction + ΔV**. The miss distance and the new orbit update live while dragging (same `PathRenderer`/`Kepler` code), and pressing EXECUTE fires the pulse. The rest of the plan is re-simulated from the new orbit, so the player sees whether the objective is still reachable with the remaining ΔV.
- **Outcome:**
  - Miss distance > safe threshold: "THREAT AVOIDED", and the mission continues.
  - Collision: mission failure, or for a small piece of debris, damage. The structural alarm and a damaged-instrument chance appear.
  - Ignoring the event is allowed, and sometimes the threat misses on its own (a lesson about the uncertainty in cheap-radar data).
- **Planning connects to this:** the reserve ΔV left after planning (shown in Planning as "RESERVE") is the safety margin for events. Spending everything on the plan is a gamble, which links to the "Keep ΔV reserves" side quest in Tasks.md.

### Hazard rates by region
Realism comes from how likely each hazard is in each place, set per mission in `missions.json`. **Height decides how dangerous a place is; time decides how long the craft is exposed to it.** Each event type has a rate `λ(h)` (expected events per hour of simulated time) that depends on the altitude band the craft is in. Each sub-step of length `Δt` rolls
```
P(event) = 1 − e^(−λ(h)·Δt)
```
A probability that depended on height alone would still need a rule for how often to roll it. Rolling every frame would tie the odds to frame rate and time-warp speed; rolling once per altitude band would give the same risk for one minute there as for ten orbits. For tuning, a rate can be read as a chance per orbit: `λ = 0.2` per hour is about a 26% chance per 92-minute orbit. Placeholder levels, to be replaced with sourced numbers (Tasks.md #4):

| Event | Low Earth orbit | Higher orbits |
|---|---|---|
| Satellite conjunction, debris shower | high | lower |
| Unknown asteroid | very low | low |
| Solar flare effects | medium | higher |
| Engine, leak and sensor faults | same everywhere | same everywhere |

### Event log (no effect on score for now)
Each event is logged as `{type, time, reacted, dv_spent, outcome}`. FinalScreen shows it as an informational list with short explanations (e.g. "Your basic radar gave you 40 s of warning; an advanced radar would have given 6 min"). **Events don't change the score directly, and avoiding a threat gives no bonus.** A collision ends the flight, and the score is computed from whatever the mission achieved up to then, through the normal scoring rules.

## Scoring (`GameState.compute_score`) → FinalScreen
Launch failure (never reached orbit) → **0**, special result screen. Otherwise the score is the sum of the parts below. The top-level weights are the team's (Scoring Missions.md): mission 50, budget 30, science 20, side quests +20 each. Avoiding a threat gives no bonus. All targets, tolerances and weights are per-mission values in `missions.json`.

**The sub-scores are a proposal, to be confirmed by the team.** They are graded rather than all-or-nothing, so every score band can be reached.

| Part | Sub-score | Points | Rule |
|---|---|---|---|
| Mission (50) | Orbit achieved | 20 | At mission end the craft is in a closed orbit with its periapsis above the atmosphere |
| | Altitude accuracy | 15 | `15 · max(0, 1 − abs(a − a_target) / tol_a)`, with `a` the semi-major axis |
| | Orbit shape | 10 | `10 · max(0, 1 − abs(e − e_target) / tol_e)` |
| | Vehicle health | 5 | `5 ×` the share of installed instruments still working. Each instrument is either working or failed (a flag set by the sensor-failure and collision events); there is no health bar |
| Budget (30) | Within budget | 25 | Full when cost ≤ budget |
| | Margin | 5 | `5 · min(1, margin / 10%)`: full when at least 10% of the budget is unspent |
| | Over budget | down to −25 | The 25 becomes `25 − p`, where `p` is the percent over budget, with a floor of −25 at 50% over. Past 25% over, it eats into the other parts |
| Science (20) | Instrument fit | 8 | `8 · stars / 3` for the best-fitting SCI instrument carried |
| | Coverage | 8 | `8 · min(1, f / f_required)`, with `f` the share of the final orbit's period spent inside the science zone |
| | Data returned | 4 | `4 · min(1, delivered / required)` (see "Science data and the data link") |

**Coverage for an altitude-band zone** `[r_lo, r_hi]` is exact from Kepler's equation, with no simulation needed. Radius grows with the eccentric anomaly `E` from periapsis to apoapsis as `r = a·(1 − e·cos E)`, and time grows as `M = E − e·sin E`:
```
E_x = cos⁻¹( clamp( (1 − r_x / a) / e , −1, 1 ) )      for x = lo, hi
f   = ( M(E_hi) − M(E_lo) ) / π
```
For a circular orbit `f` is 1 if `a` is inside the band and 0 otherwise. An open orbit has no period and scores 0.

**Side quests** (accepted in Mission select):
- Accepting a side quest **adds its budget grant** to the mission budget.
- Success: **+20** each, which raises the maximum above 100.
- Failure: a penalty by number failed, **5 / 15 / 30** for one / two / three (Scoring Missions.md).
- Proposed: a failed side quest's grant is taken back before the budget part is computed, so money already spent can put the mission over budget.

**Bands** (Scoring Missions.md): Failure 1–50, Partial Success 50–70, Success 70–90, Great Success 90–99, Perfect 100, Scientific Breakthrough 100+. FinalScreen shows the band with the Amit placeholder portraits, the table above filled in with the player's numbers, and a short explanation per line.

## Placeholder assets (`tools/generate_placeholders.py`)
Green-on-black CRT monitor frames and bezels, arrow tabs, stat chip frames, part icons (16×16) per catalogue id, stage segments + engine bells, Earth (64 px), launch-point marker, asteroid, radar dish/sweep, gauge frames, NO SENSOR static, alarm lamp on/off, Amit portraits. Each is named after what it replaces, so the team can swap in real art.

## Verification
- Run `python3 tools/generate_placeholders.py` and check every referenced PNG exists. A grep check compares `res://` paths in `.tscn`/`.gd` files against files on disk.
- **Headless Godot 4.7 checks** (`tools/check_project.sh`), run in the project folder:
  - `godot --headless --import` (imports assets and reports script/scene errors)
  - `godot --headless --check-only --script <file>` for each script
  - `godot --headless --quit-after 120 <scene>` for each scene
  
  All must be clean before a commit.
- **Physics tests (`tests/test_kepler.gd`).** Run through the shared test scene, `godot --headless res://tests/TestRunner.tscn`, which runs every `tests/test_*.gd`, prints PASS/FAIL per check and exits with a non-zero code on any failure. Checks, with μ = 3.986004×10¹⁴ m³/s² and R = 6371 km:
  - Circular orbit at 400 km: speed ≈ 7672.6 m/s, period ≈ 5545 s (92.4 min).
  - Hohmann transfer from 400 km to 800 km: pulses ≈ 109.3 m/s and ≈ 107.7 m/s.
  - Tsiolkovsky: 100 kg of propellant at Isp 300 s gives ≈ 99.7 m/s from 3,000 kg and ≈ 310.0 m/s from 1,000 kg.
  - `propagate` over one full period returns to the starting state, and energy and angular momentum stay constant along the way.
  - `state_to_elements` followed by `elements_to_state` returns the input, including for a circular orbit (`e = 0`), a clockwise orbit and an open orbit (`e > 1`).
  - An open orbit is reported as leaving Earth orbit.
- **Cross-check against GMAT (optional).** Run one reference case in GMAT with a point-mass Earth and impulsive burns, export the state at a few times, and compare with `Kepler.propagate` in the same test file. This also gives the submission a concrete use of a NASA tool.

## AI use and references (required by the hackathon rules)
The submission must describe how AI was used and list every external resource. Most of the code is written with AI tools, so the AI agent doing the work keeps both records up to date, in the same commit as the change:
- **`docs/AI_USAGE.md`**: one entry per working session: date, tool and model, what it was asked to do, which files it produced or changed, and what a team member reviewed or changed by hand. This also covers AI-made images, text and this plan.
- **`docs/REFERENCES.md`**: one entry per external resource: name, URL, licence, and where it is used. This covers data sources (every `source` in `parts.json`), documents (for example the GMAT Mathematical Specifications), code, fonts, sounds, images and tools (Godot).
- A change that uses AI or adds an external resource is not complete until both files are updated. The project-page text for the submission is assembled from these two files.

## Deferred to the next stage
- Spacecraft bus: power and mission lifetime. Until then the `power` stat of SCI parts is stored but has no effect.
- Data link version 2 (see "Science data and the data link"). Version 1 is in the first build.
- Replay loop (FinalScreen back to planning with the design kept).
- The Moon (see "Bodies are data").
- Demo video or slides and the pitch, prepared once the program is ready.

## Open decisions
- Final lists of missions, science missions, side quests and hazards (Tasks.md #1–3).
- Confirm the proposed sub-scores (see Scoring).
- Licence for the repository (the rules apply Apache 2.0 if none is chosen).