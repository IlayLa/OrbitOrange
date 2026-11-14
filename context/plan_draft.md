# OrbitOrange — Initial Godot Template (Mission Planning focus)

## Context
The repo has only vision notes (`context/Notes/*.md`) and a Godot `.gitignore`. The NASA Space Apps 2026 "Space Mission Design Game" challenge asks for mission design with real trade-offs. Our "Absolute Truths" fix it as: **2D, pixel art, Godot 4, POC, Keplerian mechanics, control-room look**. The user wants an editable starting template with placeholder assets for **telemetry screens, rocket design, and Keplerian dynamics**, with **mission planning as the main focus**. The POC main mission is a **low Earth orbit** (Tasks.md, idea #1).

Godot isn't installed in the container, and I won't download it. I'll write the `.tscn`/`.gd` files by hand, keep scenes small, and build most UI in code so mistakes in hand-written scene files can't break much.

## Step 0
Export this plan to `docs/PLAN.md` in the repo, before any code, so the team can read and edit it.

## Project layout (all new files, branch `yasha_develop`)
```
project.godot                 Godot 4.7, 640x360 viewport, stretch=canvas_items, integer scale, nearest filter (pixel art)
icon.svg
autoload/
  GameState.gd                budget, selected parts, mission plan, results; signal bus
  Kepler.gd                   pure orbital-math helpers (see below)
data/
  parts.json                  engines/pulse thrusters (max dv per pulse, pulse count, Isp) / tanks+materials / telemetry / science / decouplers (placeholder NASA-like numbers, cost, mass, Isp, thrust)
  missions.json               main mission (LEO orbit) + science objectives + side quests + hazards
scripts/
  orbit/OrbitView.gd          draws Earth, current orbit, predicted orbit, pulse markers, hazard zones, science zones
  orbit/Pulse.gd              data class: when (true anomaly / time), dv_v / dv_b (GMAT VNB frame), angle+strength helpers
  export/GmatExporter.gd      writes design + pulses as a GMAT .script
tools/gmat/                   reference GMAT scripts (circular, Hohmann, radial pulse)
tests/                        test_kepler.gd + gmat_reference/*.csv
  telemetry/TelemetryFeed.gd  true state + instrument quality -> degraded readings (noise, range, update rate, dropout, resolution)
  telemetry/TelemetryPanel.gd base class: CRT frame, title, update(reading), "NO SENSOR" state
  telemetry/{Radar,Fuel,Altitude,Attitude,Accelerometer,Engine,Structural}Panel.gd
scenes/
  MainMenu.tscn/.gd           Start New Game -> Rocket Design
  RocketDesign.tscn/.gd       separate screen; NASA-sourced part catalogue (see Rocket Design section)
  MissionPlanning.tscn/.gd    ★ main screen (below)
  ControlRoom.tscn/.gd        grid of telemetry panels + mission progress + orbit view + self-destruct (fake) button
  FinalScreen.tscn/.gd        score breakdown per Scoring Missions.md
assets/placeholders/          generated pixel PNGs (rocket parts, Earth, rocket sprite, CRT frame, buttons, radar sweep, gauge needles, hazard/asteroid, Amit portrait stubs)
tools/generate_placeholders.py  PIL script that regenerates all placeholders (swap art later by replacing PNGs with the same name)
README.md                     how to open, scene flow, where to edit what
```

## Keplerian dynamics (`autoload/Kepler.gd`)
Decision: write our own small 2D two-body solver. We checked JR Orrery (MIT, Godot 4.7+). At about 12k lines with 3D, N-body and GPU code, it's overkill for the POC. Gameplay code talks only to a thin `OrbitModel` facade (`predict_path(plan)`, `state_at(t)`, `apply_pulse(...)`), so JR Orrery can replace the backend later for the Moon/Jupiter missions in Future Prospects.
Static functions in SI units with Earth constants (μ = 3.986e14, R = 6371 km):
- `tsiolkovsky_dv(isp, m0, mf)` and `stage_dv(stages)` (summed per stage, accounting for jettisoned mass)
- `vis_viva(r, a)`, `circular_velocity(r)`, `orbital_period(a)`
- `state_to_elements(r_vec, v_vec)` -> a, e, ω, ν, periapsis/apoapsis alt
- `elements_to_state(...)` and `position_at_true_anomaly(...)`
- `propagate(elements, dt)` via Kepler's equation (Newton solve for E)
- `apply_pulse(state, direction, dv)` -> new elements: an **instantaneous impulse** that changes velocity in one step, position unchanged. There is no continuous-thrust integration anywhere.
- `hohmann_dv(r1, r2)`, which planning uses as a "suggested plan" helper
- Launch stays abstracted for the POC: the chosen launch vehicle inserts the spacecraft into its insertion orbit (if mass ≤ capacity), and Keplerian simulation starts from there. All in-mission maneuvering is spacecraft pulses.

## Rocket Design screen (separate scene: `scenes/RocketDesign.tscn`)
The player builds the vehicle here before Mission Planning. Every part comes from `data/parts.json`, a catalogue built from the NASA resources in `context/` plus public figures for real hardware.

### Data sources (from `context/NASA Space Apps Challenge description.html` → "NASA Data & Resources")
| Resource | What we take from it |
|---|---|
| **CubeSat 101** (NASA CSLI) | Spacecraft bus as CubeSat units (1U/3U/6U/12U, 10 cm cube, ~1.33 kg/U), subsystem list (structure, EPS/solar/battery, comms, OBC, ADCS, propulsion), typical power/data numbers |
| **Design and Develop Science Missions** | 4 segments, used as tabs: Launch, Space (bus + instruments), Ground (comms/ground station), User (science value) |
| **GMAT** | Impulsive-burn model (matches our pulses), standard thruster parameters (Isp, thrust), Δv bookkeeping |
| **Mission Design Lab / Concept Maturity Levels** | "Design review" panel: mass, power, data and budget margins, red/amber/green like an MDL study |
| **Webb "Build it yourself" game** | UX reference for part picking with trade-off explanations |
| **NASA Mission Viz** | Visual reference for the part/vehicle preview |

The NASA sites can't be reached from this session, so numbers come from the context descriptions and well-known public specs. Each part gets a `source` field and an `approx: true` flag, so Yasha (Tasks.md #4) can verify and replace them later.

### Part schema (`parts.json`)
```json
{ "id": "thr_green_mono", "name": "Green Monoprop Thruster (ASCENT/GPIM-class)",
  "category": "propulsion", "tier": 2,
  "cost_musd": 1.2, "mass_kg": 2.5, "power_w": 20, "volume_u": 1,
  "stats": { "isp_s": 230, "max_dv_per_pulse_ms": 50, "pulse_count": 12, "propellant_kg": 1.5 },
  "telemetry_quality": null,
  "mission_fit": { "leo_insertion": 2, "debris_avoid": 1 },
  "tradeoff": "Higher Isp than cold gas means more Δv per kg, but costs more and needs power to heat the catalyst.",
  "source": "GMAT thruster model; NASA GPIM mission", "approx": true }
```
`mission_fit` scores 0–3 per objective/science mission/side quest in `missions.json`. The UI turns these into "★★☆ complements Earth Imaging" badges and adds them to the predicted science score.

### Catalogue for the POC (3 tiers per category, approximate numbers)
| Tab | Category | Basic | Standard | Advanced | How it complements the mission |
|---|---|---|---|---|---|
| Launch | Launch vehicle | Rideshare slot (Falcon 9 Transporter-class), ~$6k/kg, fixed 500 km SSO | Small launcher (Electron-class), ~$7.5M, ≤300 kg LEO, choose orbit | Dedicated medium (Minotaur-class), high cost, any LEO | Payload capacity must be ≥ spacecraft mass (hard check). The chosen insertion orbit sets the start of Mission Planning, so a better launcher means fewer pulses needed |
| Space | Structure / bus | 1U (1.33 kg max) | 3U (4 kg) | 6U (12 kg) | Sets volume slots for all other parts, plus mass and cost |
| Space | Power | Body-mounted solar 2 W + small battery | Deployable panels 20 W | Deployable 40 W + large battery | Power budget: instruments + comms + thruster heating must fit |
| Space | Propulsion (pulses) | Cold gas (Isp ~70 s, few small pulses, cheap, safe) | Green monoprop (Isp ~230 s) | Hydrazine monoprop (Isp ~220 s, more pulses, highest thrust per pulse, costly, heavy) | Δv per pulse × pulse count = maneuver budget in Mission Planning |
| Space | ADCS | Magnetorquers (coarse) | Reaction wheels | Star tracker + wheels | Pulse direction accuracy (cheap ADCS adds angle error to pulses); Attitude panel quality |
| Space | Onboard computer | Basic | Rad-tolerant | Rad-hard | Telemetry dropout rate; resists the radiation-belt hazard |
| Ground | Comms | UHF (~9.6 kbps) | S-band (~1 Mbps) | X-band (~100 Mbps) | Data budget: science data must downlink. Also caps the update rate of **all** telemetry panels |
| Space | Telemetry sensors | Radar, Altimeter, IMU/Accelerometer, Fuel gauge, Structural sensor, each in 3 tiers | | | Feeds the Control Room panels via `TelemetryFeed` (range, noise, update_hz, resolution, dropout) |
| User | Science instruments | Camera (Earth imaging), Magnetometer (space weather), Langmuir probe / drag sensor (atmosphere), Debris radar (debris survey) | | | Each matches a science mission in `missions.json` with a high `mission_fit`. Adds mass, power and data |

### Screen layout (640×360, pixel art)
- **Left (tabs):** Launch / Space / Ground / User, then a category list, then part cards (placeholder icon, name, tier pips, cost, mass, power). Hovering a card shows the `tradeoff` text and its `source`.
- **Center:** pixel preview of the stacked vehicle (launcher stages + CubeSat with slot grid). Parts snap into the CubeSat's U slots. Stage separation is shown as dashed lines.
- **Right ("Design Review", MDL-style):** live bars with green/amber/red margins:
  - Budget: total cost vs. mission budget (in $M)
  - Mass: spacecraft mass vs. launcher capacity
  - Power: generation vs. draw
  - Data: generated vs. downlink capacity
  - Δv: pulse Δv budget (Σ via Tsiolkovsky on the spacecraft's wet/dry mass) and pulse count
  - Mission fit: per-objective stars from installed parts, plus a predicted science score
- **Bottom:** "Back", "Clear", and "To Mission Planning". The last is disabled while a hard constraint fails (mass > capacity, power < 0, no propulsion, no comms), with a tooltip explaining why.
- The selection is stored in `GameState.rocket` (`{parts: [...], derived: {mass, power, dv, pulses, cost, telemetry_quality}}`). Mission Planning and the Control Room read only `derived`.

### Files
- `scenes/RocketDesign.tscn/.gd`, `scripts/design/PartCard.gd`, `scripts/design/DesignReview.gd`, `scripts/design/RocketBuilder.gd` (pure functions that compute `derived` from parts, so it's easy to test)
- `data/parts.json`, `data/missions.json` (science missions, side quests, hazards, `fit` keys)
- Placeholders: `assets/placeholders/parts/<id>.png` (16×16 / 32×32 icons) and `assets/placeholders/vehicle/*.png` (stages, CubeSat frames)

## How GMAT fits in
GMAT is NASA's desktop mission-analysis tool (C++, with its own `.script` language). **It does not run inside Godot.** We use it in four ways:

**1. Rocket Design: part fields use GMAT's resource model.** Propulsion parts store exactly the fields GMAT's resources use, with the same names and units:

| Our `parts.json` field | GMAT resource.field | Used in game for |
|---|---|---|
| `dry_mass_kg` (sum of parts) | `Spacecraft.DryMass` | total mass, launcher capacity check |
| `propellant_kg` | `ChemicalTank.FuelMass` | fuel gauge, Δv |
| `isp_s` | `ChemicalThruster.Isp` / `ImpulsiveBurn.Isp` | Δv via Tsiolkovsky (what GMAT's `DecrementMass = true` does) |
| `max_dv_per_pulse_ms`, `pulse_count` | game limits on `ImpulsiveBurn.Element1..3` | pulse slider caps, pulse counter |

The Design Review's Δv bar uses the same math GMAT uses, so a player's design means the same thing in both tools.

**2. Mission Planning / Kepler: our pulse = GMAT's `ImpulsiveBurn`.** GMAT models an instant Δv in the VNB frame (V = along velocity, N = orbit normal, B = in-plane perpendicular). Our 2D pulse is the V and B components (N = 0 because we're 2D). `Pulse.gd` stores `dv_v`, `dv_b`, and the angle/strength UI converts to them.

**3. Validation: GMAT produces reference data for our tests.** In `tools/gmat/` we keep `.script` files for reference cases: a 400 km circular orbit, a 2-pulse Hohmann raise, a single radial pulse. Someone with GMAT on their PC runs them once and saves the `ReportFile` output (time, X, Y, VX, VY, SMA, ECC) as CSV in `tests/gmat_reference/`. A test script (`tests/test_kepler.gd`, run headless) propagates the same cases with `Kepler.gd` and checks we're within tolerance. This shows the judges our physics matches NASA's tool.

**4. "Export to GMAT" button (Mission Planning → nice-to-have).** `scripts/export/GmatExporter.gd` writes the player's spacecraft + pulse plan as a `.script` (Spacecraft, ChemicalTank, ImpulsiveBurn per pulse, Propagate/Maneuver sequence). Players can open their own mission in NASA's real tool, which supports the challenge's educational goals.

GMAT isn't installed here, so I'll write the reference scripts and the exporter by hand from GMAT's documented syntax. Running them on a PC is a later step, and until real GMAT CSVs exist the tests fall back to analytic expectations (vis-viva, period).

## Mission Planning screen (the focus)
Layout: the orbit view fills the left ~2/3, the side panel takes the right third.
- **Orbit view**: Earth sprite, parking orbit (solid), predicted orbit after the planned pulses (dashed, recomputed live), science-target zones (highlighted arcs/altitude bands), hazard zones (debris band, asteroid sprite) from missions.json.
- **Pulses only (no full engine burns)**: click on the orbit to place a pulse. Drag an arrow handle to set direction and strength, or use sliders for the angle and Δv. Strength is clamped to the engine's max Δv per pulse. The total pulse count is limited by the rocket's design. Delete with right-click. The predicted orbit chains each pulse in order: propagate to the pulse point, apply the impulse, continue.
- **Side panel**:
  - Δv budget bar: spacecraft pulse Δv (from Rocket Design) − Σ planned pulse Δv = reserve (red when negative), plus a "pulses used / available" counter
  - Planned orbit readout: apoapsis, periapsis, period, eccentricity
  - Objectives checklist: main mission, chosen science mission (pick 1), optional side quests (each adds budget and difficulty)
  - Hazard warnings: the predicted orbit crosses a hazard zone
  - Budget: cost of parts vs mission budget
  - Buttons: "Suggest Hohmann (2 pulses)", "Back to Rocket Design", "Launch" (-> Control Room)
- The plan is stored in `GameState.mission_plan`, so the Control Room plays it back.

## Telemetry screens (Control Room): driven by the instruments chosen in Rocket Design
Each panel uses the same CRT frame and green-on-black pixel style, fed from a simple sim loop: Kepler propagation, with each pulse applied as an instant velocity change when the craft reaches its point.

**Instrument → telemetry quality.** Every telemetry part in `parts.json` has tiers (e.g. `radar_basic` / `radar_standard` / `radar_advanced`) with cost, mass, power, and a `quality` block:
- `range_km`: how far away objects are detected
- `noise`: σ of the position/distance error, randomized each update
- `update_hz`: refresh rate (cheap = laggy, choppy readout)
- `resolution`: what is shown about a detected object. 0 = blip only, 1 = distance and bearing, 2 = adds size/shape outline and relative velocity
- `dropout`: chance a frame is lost (static/"NO SIGNAL" flicker)

A `TelemetryFeed` (scripts/telemetry/TelemetryFeed.gd) takes the true sim state, degrades it with the installed instrument's quality, and hands the result to its panel. Panels only ever see the degraded data. **Missing instrument → the panel shows "NO SENSOR INSTALLED"** (placeholder static image). Examples:
- Radar: a basic radar shows noisy blips at short range. An advanced radar shows asteroid/debris outlines, exact distance and closing speed.
- Altitude/Attitude/Accelerometer/Fuel: noise and update rate scale with the tier.
- Engine: always present (comes with the engine part). Shows pulse armed/fired, pulses remaining, and last pulse Δv.
- Structural: optional sensor. Without it, damage is invisible until failure.

Rocket Design shows each instrument's stats next to a small preview of the panel's quality, so the trade-off (cost/mass vs. information) is visible before launch. Mission Planning also uses the radar tier: hazard zones beyond the radar's detection quality are drawn as fuzzy "uncertain" areas.
Mission progress panel: time and distance to the next objective, plus the objectives list. Self-destruct button: a Doofenshmirtz-style joke popup, nothing is destroyed. At mission end, compute the score and go to FinalScreen.

## Scoring (`GameState.compute_score`)
Per Scoring Missions.md: success 50, budget compliance 30, science choice 20, side quests +20 each, and failure penalties 5/15/30. Score bands map to Failure / Partial / Success / Great / Perfect / Breakthrough, and the band shows on FinalScreen with an Amit placeholder portrait.

## Verification
- Run `python3 tools/generate_placeholders.py` to confirm every PNG is created.
- Sanity-check Kepler math in a Python port with a few asserts: 400 km circular orbit gives v ≈ 7.67 km/s and period ≈ 92.6 min; a LEO→GEO Hohmann needs ≈ 3.9 km/s.
- Target **Godot 4.7** (the user's installed version): `config/features=PackedStringArray("4.7", "GL Compatibility")`. Scripts use static typing so the parser catches errors.
- This cloud session can't reach the user's PC: no Remote Control folders are shared. So I'll keep scenes minimal and hand-check `.tscn` headers and ext_resource paths. I'll add `tools/check_project.sh` that runs locally:
  - `godot --headless --path . --import` (imports assets, reports script/scene errors)
  - `godot --headless --path . --check-only --script <each .gd>` for every script
  - `godot --headless --path . --quit-after 120 res://scenes/<each>.tscn` to load each scene briefly
- Commit and push to `yasha_develop` (no PR). The user runs the check script on their PC and pastes any errors back, and I fix them.
- Alternative: share the repo folder through Remote Control (Claude desktop app → Settings → Claude Code → Remote Control). Then I could run Godot 4.7 on the user's PC directly.