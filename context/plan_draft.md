# OrbitOrange — Initial Godot Template (redesigned to match the team sketch)

## Context
The NASA Space Apps 2026 "Space Mission Design Game" asks for mission design with real trade-offs. From `context/Notes/Absolute Truths.md`: **2D, pixel art, Godot (4.7), POC, Keplerian mechanics, control-room look**. The POC mission is a **low Earth orbit** (Tasks.md idea #1). The user wants an editable template with placeholder assets for **telemetry screens, rocket design and Keplerian dynamics**, focused on **mission planning**.

The visual design comes from the team sketch on `main`: `context/WhatsApp Image 2026-11-14 at 12.10.59.jpeg`. First step: fast-forward `yasha_develop` to `origin/main` (it adds that image and `context/plan_draft.md`).

## Visual design (from the sketch)
The game is **one control-room console with two halves**: **PLANNING ◀ | ▶ EXECUTION**. The player switches with the arrow tabs at the top (slide transition). On a 640×360 pixel viewport each half fills the screen. EXECUTION stays locked until "Launch".

### PLANNING half (`scenes/PlanningConsole.tscn`): overview + two zoom views
**Overview** (top-left of the sketch): two monitors, the **rocket monitor** on the left and the **orbit monitor** on the right, with compact `$` `ΔV` `W` chips on top. Each monitor has a **🔍 zoom button** (and click-to-zoom). Zooming is an animated camera/scale move into that monitor. Pressing "◀ back" or Esc zooms out. Stages and part cards are **not** shown in the overview.

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
│ │objective│ │  radar → │  RADAR   │         │ θ φ ψ    │    │
│ │ list    │ │          └──────────┘         └──────────┘    │
│ └────────┘ │  [Altitude]  [Fuel]           [Acc x y z]     │
└────────────┴──────────────────────────────────────────────┘
```
Left column: mission time, ΔV remaining, objective list. Instrument wall: **ALARM** (flashing warnings), **TEMP** (engine/tank temperature), **RADAR** (center), **Angles θ φ ψ** (attitude), **Altitude**, **Fuel**, **Acc x y z** (accelerometer). The fake self-destruct button sits in a corner.

## Project layout (branch `yasha_develop`)
```
project.godot                 Godot 4.7, 640x360, stretch canvas_items, integer scale, nearest filter, GL Compatibility
autoload/GameState.gd         budget, rocket (stages+parts+derived), mission plan, results, signals
autoload/Kepler.gd            2D two-body math
data/parts.json               ENG / MAT / TEL / SCI catalogue (NASA-sourced, approx flags)
data/missions.json            LEO mission, science missions, side quests, hazards, launch site
data/events.json              random event definitions (see Random events)
scenes/MainMenu.tscn          -> Console
scenes/Console.tscn           holds both halves, PLANNING/EXECUTION arrow tabs, slide transition
scenes/PlanningConsole.tscn   rocket preview + parts column + stat chips + orbit view + stage list
scenes/RocketDesign.tscn      rocket preview monitor (separate scene, embedded)
scenes/ExecutionConsole.tscn  instrument wall
scenes/FinalScreen.tscn       score + task explanations + Amit portrait
scripts/design/{RocketBuilder,PartCard,PartDetailsPopup,StatChips}.gd
scripts/ui/ZoomMonitor.gd     overview <-> zoom animation for a monitor
scripts/orbit/EngineList.gd   engine rows, select engine -> pulse placement mode
scripts/orbit/{OrbitModel,OrbitView,Pulse,PathRenderer}.gd
scripts/execution/{EventDirector,EmergencyManeuver,ThreatModel}.gd
scripts/telemetry/{TelemetryFeed,TelemetryPanel}.gd + {Radar,Angles,Altitude,Fuel,Acc,Temp,Alarm}Panel.gd
tools/generate_placeholders.py   PIL placeholders (replace PNGs keeping names)
tools/check_project.sh        headless Godot checks for the user's PC
assets/placeholders/{console,parts,vehicle,orbit,telemetry,portraits}/*.png
README.md
```

## Rocket design (Planning: left monitor + parts column + stage list)
**Rocket = stages.** Each stage = engine (ENG) + tank/structure material (MAT). Engines left after the ascent perform the pulses (solid = one pulse, liquid = several). The top stage carries the payload: TEL and SCI instruments.

**ΔV:** Tsiolkovsky per engine, in firing order, with spent stages jettisoned (`Kepler.stage_dv`). The `ΔV` chip shows total ΔV. Launch and orbit use the same engines (see Orbit / pulse planning).

**Data sources** (`context/NASA Space Apps Challenge description.html` → NASA Data & Resources). The NASA sites aren't reachable from this session, so numbers are public figures with `"approx": true` and a `source` field, for Yasha (Tasks.md #4) to verify:
| Resource | Used for |
|---|---|
| CubeSat 101 | payload bus sizes (1U/3U/6U), subsystems, power/data figures for TEL/SCI parts |
| Design & Develop Science Missions | launch / space / ground / user segments → stage parts vs. payload vs. comms vs. science value |
| GMAT | propulsion fields (`Isp`, `FuelMass`, `DryMass`, tank `Pressure`/`Temperature`), pulse = `ImpulsiveBurn` |
| Mission Design Lab / CMLs | green/amber/red margins on the $ / ΔV / W chips |
| Webb "Build it yourself", Mission Viz | UX/visual references for part picking and the rocket preview |

**Part schema** (one entry, all fields GMAT-compatible where possible):
```json
{ "id": "eng_rl10", "tab": "ENG", "name": "RL10-class upper-stage engine", "type": "liquid",
  "cost_musd": 10, "mass_kg": 300, "stats": { "isp_s": 465, "thrust_kn": 110, "propellant_kg": 2000 },
  "mission_fit": { "leo_insertion": 3 }, "tradeoff": "Very efficient, expensive; ideal upper stage.",
  "source": "public spec; GMAT ChemicalThruster fields", "approx": true }
```

**POC catalogue (3 tiers each, approximate):**
| Tab | Parts | Key stats | How it complements the mission |
|---|---|---|---|
| ENG, solid | small solid kick motor, Star-class solid, large solid booster | Isp, propellant, mass, cost (cheap) | Cheap launch muscle. In orbit: **one fixed-ΔV pulse, direction only** |
| ENG, liquid | cold-gas thruster, Rutherford-class (Isp ~343 s vac), Merlin-class (Isp ~282 s SL / 348 s vac), RL10-class (Isp ~465 s) | Isp, thrust, cost | Upper stage: **pulses with chosen direction + ΔV**. Higher Isp = more ΔV per kg, at higher cost |
| MAT | aluminium tank, Al-Li tank, carbon-composite tank; blow-down vs. regulated pressurization | dry mass, propellant capacity, cost | Lighter tanks = more ΔV. Blow-down is cheaper, but later pulses get weaker (GMAT `PressureModel`) |
| TEL | **proximity/collision radar** (navigation; *not* the SCI imaging radar), altimeter, IMU/accelerometer, attitude sensor, fuel gauge, temperature sensor, each in 3 tiers | range, noise, update_hz, resolution, dropout | Decides the quality of each EXECUTION panel. Missing = "NO SENSOR" |
| SCI | camera (Earth imaging), magnetometer (space weather), drag/Langmuir probe (atmosphere), **SAR imaging radar** (Earth-surface science; *not* the TEL proximity radar) | mass, power, data, cost, science value | Each matches a science mission (`mission_fit` 0–3, shown as stars) |

The `$`, `ΔV` and `W` chips plus mission-fit stars update live. "Launch" is disabled (with a tooltip) when the budget is exceeded or there's no engine. A plan that doesn't reach orbit *can* be launched: it fails (see Launch).

## Orbit / pulse planning (Zoom RIGHT, ★ focus)
**Scene:** Earth, launch point (missions.json), the trajectory, pulse points with ΔV arrows, science zones (altitude bands).

**Planning hazards = broad danger zones.** Planning shows large areas from missions.json (debris belt band, radiation belt, an asteroid-corridor sector), drawn as hatched red regions. They are the same for every rocket; instruments don't affect them. Specific objects inside these zones are revealed only during EXECUTION, at close range by the TEL radar.

### Launch: simple ballistic physics
- In the engine list the player marks which engines fire **at launch** (default: the first one). Their ΔV (Tsiolkovsky, firing in order with jettison) minus a fixed **loss term** (gravity + drag, ~1.5 km/s, tunable in missions.json) gives the burnout speed. The player sets the **launch angle** with a slider.
- The ascent is a **ballistic arc**: launch point + burnout velocity, then free flight under gravity only. In 2D two-body physics a ballistic arc *is* a Kepler conic, so the same `Kepler.propagate` draws it. No extra physics needed.
- A trajectory that starts at the surface always comes back down, unless a pulse raises the periapsis. So, as in the sketch, the player places a **ΔV pulse near the top of the arc** with a remaining engine to circularize.
- **Launch failure:** if the final planned path hits Earth or has periapsis inside the atmosphere (< 100 km), the arc is drawn red and planning shows "WILL NOT REACH ORBIT". If launched anyway, EXECUTION shows the crash and FinalScreen shows a special **"Rocket didn't launch successfully"** result with **score 0**.

### Pulses (instant ΔV, no continuous burns)
Select an engine in the list:
- **Solid → one point.** Place it and rotate its arrow (direction only). ΔV is fixed: the motor burns all its propellant.
- **Liquid → multiple points.** Each gets direction + ΔV (arrow length or slider). No per-pulse cap. The only limit is the engine's remaining propellant.
- Order: points are processed in time order, and an engine's points must come after the previous engine's last point.

### Why ΔV values change while planning (mass bookkeeping)
ΔV from a given amount of propellant depends on how much mass it pushes: `ΔV = Isp · g0 · ln(m_before / m_after)`.
1. At launch the rocket weighs everything: all engines, tanks, propellant and payload.
2. Each pulse burns propellant: `m_burned = m · (1 − e^(−ΔV / (Isp·g0)))`. The rocket is now lighter.
3. When an engine is spent (solid after its single point, liquid when its propellant runs out), its stage (engine + tank dry mass) is **jettisoned**, and the rocket is lighter again.
4. So the *same* propellant in a later engine buys **more** ΔV than it would at launch. Example: 100 kg of propellant at Isp 300 s gives ~100 m/s on a 3,000 kg rocket, but ~310 m/s after it's down to 1,000 kg.

In the UI, `RocketBuilder.simulate_masses(plan)` re-runs this chain after every edit. Each engine row shows its current available ΔV, and when an earlier pulse is changed, later rows flash the difference (e.g. "+40 m/s"). A solid engine's fixed ΔV also shifts, depending on how much mass is left when it fires.

### Drawing the path with several pulses (`PathRenderer.gd`)
The plan is a chain of segments: segment *i* is the conic flown between pulse *i* and pulse *i+1*.
- **Flown path:** each segment's arc is drawn solid in the color of the engine that created it, so the colors read like a timeline.
- **Final orbit:** the last segment's full ellipse is drawn bright. It's the result.
- **Ghosts only for the selected or hovered pulse,** to avoid clutter: the full ellipse *before* that pulse is drawn faint (25% alpha, dotted) and the ellipse *after* it bright dashed. Other pulses show only their arrows.
- **While dragging,** a snapshot of the path taken when the drag started stays as a faint ghost. Pulses after the dragged one are re-simulated live on the new path, so the player sees how one change ripples through the rest of the plan.

**Readouts** (overlay): apoapsis, periapsis, period, eccentricity, ΔV left per engine, "inside danger zone" warnings. The plan is stored in `GameState.mission_plan` (`{launch: {engines, angle}, pulses: [{engine_id, time, dv_v, dv_b}]}`) and EXECUTION replays it.

## Keplerian dynamics (`autoload/Kepler.gd` behind `OrbitModel`)
We write our own small 2D two-body solver. JR Orrery (MIT, ~12k lines, 3D/N-body/GPU) is overkill for the POC. `OrbitModel` (`predict_path(plan)`, `state_at(t)`, `apply_pulse`) keeps it swappable for future Moon/Jupiter missions.
SI units, Earth μ = 3.986e14 and R = 6371 km: `tsiolkovsky_dv`, `stage_dv`, `vis_viva`, `circular_velocity`, `orbital_period`, `state_to_elements`, `elements_to_state`, `propagate` (Newton solve of Kepler's equation), `apply_pulse(state, dv_v, dv_b)` (instant velocity change), `launch_state(site, speed, angle)`, `hits_surface(path)`, `solid_pulse_dv`, `liquid_dv_available`, `propellant_for_dv`.

## How GMAT is used
GMAT does not run inside Godot. For now it's a reference for data and conventions only:
1. **Part fields mirror GMAT** (`DryMass`, `FuelMass`, `Isp`, tank `Pressure`/`Temperature`/`PressureModel`), so our ΔV/mass math matches GMAT's `DecrementMass`.
2. **Pulses = GMAT `ImpulsiveBurn` in the VNB frame.** In 2D we use V (along velocity) and B (in-plane perpendicular). `Pulse.gd` stores `dv_v`/`dv_b`, and the arrow UI converts to and from them.

## Execution instruments (driven by TEL parts)
Sim loop: Kepler propagation, with pulses applied at their points. `TelemetryFeed` degrades the true state per installed instrument (`range_km`, `noise`, `update_hz`, `resolution` 0 blip / 1 distance+bearing / 2 shape+relative velocity, `dropout`). Panels only see degraded data. Missing sensor → "NO SENSOR".
- **RADAR (TEL proximity radar):** reveals specific objects (debris pieces, asteroid) inside the planning danger zones as the craft gets close. Cheap = noisy short-range blips. Expensive = object outlines, distance, closing speed, at longer range.
- **Angles θ φ ψ, Altitude, Acc x y z, Fuel:** noise and refresh rate scale with the tier.
- **TEMP:** engine/tank temperature and pressure (GMAT `ChemicalTank` fields).
- **ALARM:** aggregates warnings (hazard proximity, low fuel, over-temperature, structural stress from strong pulses; the structural model is a gameplay abstraction, as no NASA data was found).
- **Left column:** mission time, ΔV remaining, objective list with time/distance to the next objective.

## Random events during EXECUTION
Execution isn't just watching the plan play out. An `EventDirector` throws random events at the mission, and the player can react with an **emergency pulse** paid from the **reserve ΔV**.

### Event catalogue (`data/events.json`, easy to extend)
| Event | What happens | How to save the mission |
|---|---|---|
| **Unknown asteroid** | An asteroid appears on an intercept course, with a time to impact | Pulse to change the orbit so the closest approach is > safe distance |
| **Satellite conjunction** | Predicted collision with another satellite (closest approach distance + time shown) | Small avoidance pulse (prograde/retrograde usually suffices) |
| **Engine malfunction** | One engine: loses part of its ΔV (Isp drop / leak), fails completely, or (solid) won't ignite | Re-plan the remaining pulses with the other engines. Planned pulses on the dead engine turn red |
| **Propellant leak** | One liquid engine's propellant drains over time | Use it now (pulse early) or lose it |
| **Sensor failure** | A TEL panel goes "NO SIGNAL" for the rest of the mission | No pulse needed. The player flies with less information |
| **Solar flare** | Telemetry dropout/noise spikes for a while; a cheap onboard computer may glitch | Wait it out. Better TEL/OBC parts reduce the effect |
| **Debris shower** | Several fragments while crossing the planning debris zone | One or more avoidance pulses |

### How it works
- **When:** events are rolled during the flight (seeded RNG so a run can be replayed). Probability rises inside the planning **danger zones** and with side quests. Each side quest in missions.json lists its **related event types** (e.g. "Debris survey" → debris shower, satellite conjunction). Accepting it raises those events' chance a lot (`related_multiplier`, e.g. ×3) and all other events only slightly (`unrelated_bonus`, e.g. +5%). Each event also has a `weight`, `min_time` and `in_zone_multiplier` in events.json.
- **Detection depends on the instruments:** the warning time before impact scales with the TEL radar's `range_km`. A cheap radar spots the asteroid late (little time, more ΔV needed). With no radar, the first warning is the ALARM a few seconds before impact. This is the payoff of buying good telemetry in Rocket Design.
- **Alert:** ALARM flashes, the sim **slows to 1× and pauses** on the first alert, and an **Emergency Maneuver overlay** opens over the radar monitor. It's a mini orbit view showing the threat's predicted path, the craft's path, the closest-approach point and the miss distance.
- **Reacting:** the player picks an available engine from the reserve. Same rules as planning: **solid = one point, direction only, fixed ΔV; liquid = choose direction + ΔV**. The miss distance and the new orbit update live while dragging (same `PathRenderer`/`Kepler` code), and pressing EXECUTE fires the pulse. The rest of the plan is re-simulated from the new orbit, so the player sees whether the objective is still reachable with the remaining ΔV.
- **Outcome:**
  - Miss distance > safe threshold: "THREAT AVOIDED", and the mission continues.
  - Collision: mission failure, or for a small piece of debris, damage. The structural alarm and a damaged-instrument chance appear.
  - Ignoring the event is allowed, and sometimes the threat misses on its own (a lesson about the uncertainty in cheap-radar data).
- **Planning connects to this:** the reserve ΔV left after planning (shown in Planning as "RESERVE") is the safety margin for events. Spending everything on the plan is a gamble, which links to the "Keep ΔV reserves" side quest in Tasks.md.

### Event log (no effect on score for now)
Each event is logged as `{type, time, reacted, dv_spent, outcome}`. FinalScreen shows it as an informational list with short explanations (e.g. "Your basic radar gave you 40 s of warning; an advanced radar would have given 6 min"). **Events don't change the score.** A collision ends the flight, and the score is computed from whatever the mission achieved up to then, through the normal scoring rules.

## Scoring hooks
Each event is logged with `{type, time, reacted, dv_spent, outcome}`. FinalScreen lists the events with a short explanation (e.g. "Your basic radar gave you 40 s of warning; an advanced radar would have given 6 min"). A threat avoided adds a small bonus within the existing 100-point system, and a collision applies failure rules.

## Scoring (`GameState.compute_score`) → FinalScreen
Launch failure (never reached orbit) → **0**, special result screen. Otherwise per Scoring Missions.md: success 50, budget 30, science 20, side quests +20 each, failure penalties 5/15/30. Bands: Failure / Partial / Success / Great / Perfect / Breakthrough, shown with the Amit placeholder portraits and per-task explanations.

## Placeholder assets (`tools/generate_placeholders.py`)
Green-on-black CRT monitor frames and bezels, arrow tabs, stat chip frames, part icons (16×16) per catalogue id, stage segments + engine bells, Earth (64 px), launch-point marker, asteroid, radar dish/sweep, gauge frames, NO SENSOR static, alarm lamp on/off, Amit portraits. Each is named after what it replaces, so the team can swap in real art.

## Verification
- Run `python3 tools/generate_placeholders.py` and check every referenced PNG exists. A grep check compares `res://` paths in `.tscn`/`.gd` files against files on disk.
- **Godot 4.7 on the user's PC via Remote Control.** Once the folder is shared, I connect to it and run, in the project folder:
  - `godot --headless --import` (imports assets and reports script/scene errors)
  - `godot --headless --check-only --script <file>` for each script
  - `godot --headless --quit-after 120 <scene>` for each scene
  
  I fix errors until all are clean. Until the folder is shared, the same commands go in `tools/check_project.sh` for the user to run.
- Commit and push to `yasha_develop` (no PR). Export this plan as a .md to the scratchpad (not committed), per the user's choice.