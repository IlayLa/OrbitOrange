# Asset swap report

What the asset swap (`docs/ASSET_SWAP_PLAN.md`) replaced, and what is still a placeholder or a Godot default. It was built from the tree on `main` after [PR #30](https://github.com/IlayLa/OrbitOrange/pull/30) and the placeholder removal (step H), not from the sessions' notes.

Run-time art lives in `assets/art/` and `assets/ui/`. The team's source art stays in `design/`. Three scripts rebuild the run-time files from the source art, so re-run them when the artist changes a file:

- `tools/build_part_icons.gd`: part icons.
- `tools/build_button_skin.gd`: the button skin.
- `tools/build_pixel_font.gd`: the pixel font.

## Swapped

### Part icons (29)
Each icon is one 40×40 canvas drawn at 20 px (built by `tools/build_part_icons.gd`, [#27](https://github.com/IlayLa/OrbitOrange/pull/27)). Files: `assets/art/parts/<category>/<part id>.png`. Sources are in `design/construction/`.

| Part id | Source | PR |
|---|---|---|
| `engine_cold_gas` | `engines/engine_coldgas.png` | [#14](https://github.com/IlayLa/OrbitOrange/pull/14) |
| `engine_solid_kick` | `engines/engine_star37.png` | #14 |
| `engine_solid_basic` | `engines/engine_star48.png` | #14 |
| `engine_liquid_small` | `engines/engine_rutherford.png` | #14 |
| `engine_liquid_basic` | `engines/engine_merlin.png` | #14 |
| `engine_solid_booster` | `engines/engine_orion.png` | #14 |
| `engine_liquid_hydrogen` | `engines/engine_RL10.png` | #14 |
| `tank_aluminium_basic`, `tank_aluminium_blowdown` | `materials/materials_aluminum.png` ¹ | [#19](https://github.com/IlayLa/OrbitOrange/pull/19), #27 |
| `tank_aluminium_lithium_regulated`, `tank_aluminium_lithium_blowdown` | `materials/materials_Al-Li.png` ¹ | #19, #27 |
| `tank_composite_regulated`, `tank_composite_blowdown` | `materials/materials_carbon.png` ¹ | #19, #27 |
| `telemetry_altimeter_basic` | `telemetry/tele_altmeter.png` | [#18](https://github.com/IlayLa/OrbitOrange/pull/18) |
| `telemetry_altimeter_precise` | `telemetry/tele_betteraltmeter.png` | #18 |
| `telemetry_attitude_sun_sensor` | `telemetry/tele_sunsensor.png` | #18 |
| `telemetry_attitude_star_tracker` | `telemetry/tele_startracker.png` | #18 |
| `telemetry_fuel_gauge` | `telemetry/tele_fuel.png` | #18 |
| `telemetry_temperature_sensor` | `telemetry/tele_temperature.png` | #18 |
| `telemetry_computer_basic` | `telemetry/tele_computer.png` | #18 |
| `telemetry_computer_hardened` | `telemetry/tele_bettercomputer.png` | #18 |
| `telemetry_radar_basic`, `_standard`, `_advanced` | `telemetry/tele_radar.png` ² | #18 |
| `science_camera_basic` | `science/science_camera.png` | [#17](https://github.com/IlayLa/OrbitOrange/pull/17) |
| `science_camera_high_resolution` | `science/science_bettercamera.png` | #17 |
| `science_magnetometer` | `science/science_magnetometer.png` | #17 |
| `science_atmosphere_probe` | `science/science_atmoprobe.png` | #17 |
| `science_imaging_radar` | `science/science_radar.png` | #17 |

¹ No tank drawing exists. The build script draws a simple tank shape filled with the material swatch: tall for "regulated", short for "blowdown".
² One sprite is shared by the three radar tiers.

### Final screen (portraits and backgrounds)
Each band has its own end-screen mock-up, with Amit and the band's speech bubble in the AMIT box. The orbit chart and event timeline moved to a "Flight log" page. Done in [#15](https://github.com/IlayLa/OrbitOrange/pull/15), [#24](https://github.com/IlayLa/OrbitOrange/pull/24) and [#29](https://github.com/IlayLa/OrbitOrange/pull/29); code in `scripts/mission/FinalScreen.gd`.

| Band | Background (`assets/art/screens/end/`) ← `design/end screens/` | Amit (`assets/art/portraits/`) | Speech bubble |
|---|---|---|---|
| Failure | `final_failure.png` ← `final_failure.png` | `amit_concerned` or `amit_judging` (picked at random) | — |
| Partial Success | `final_partial_success.png` ← `final_partial.png` | `amit_explaining` | — |
| Success | `final_success.png` ← `final_success.png` | `amit_happy` | — |
| Great Success | `final_great_success.png` ← `final_greatsuccess.png` | `amit_greatsuccess` ³ | "Great Success!!" |
| Perfect | `final_perfect.png` ← `final_perfect.png` | `amit_greatsuccess` ³ | "I Like It - Perfect" |
| Scientific Breakthrough | `final_scientific_breakthrough.png` ← `final_eureka.png` | `amit_greatsuccess` ³ | "I Like It - Breakthrough", with fireworks |

³ One sprite is shared by the three top bands. The background and the bubble tell them apart.

### Screens, buttons and font
| What | Run-time file | Source | PRs |
|---|---|---|---|
| Mission select background | `res://design/mission_choice.png` (`ScreenLayout.MISSION_SELECT_BACKGROUND_PATH`) | `design/mission_choice.png` | [#23](https://github.com/IlayLa/OrbitOrange/pull/23), [#28](https://github.com/IlayLa/OrbitOrange/pull/28) |
| Button skin (normal, pressed, focus, hover) | `assets/ui/ui_theme.tres`. The pixels are stored inside the theme, so a fresh clone loads it before its first import | `design/buttons.png` | [#16](https://github.com/IlayLa/OrbitOrange/pull/16), [#21](https://github.com/IlayLa/OrbitOrange/pull/21), [#25](https://github.com/IlayLa/OrbitOrange/pull/25) |
| Pixel font (project-wide, `gui/theme/custom_font`) | `assets/ui/pixel_font.tres` | `design/template.png` | [#20](https://github.com/IlayLa/OrbitOrange/pull/20), [#22](https://github.com/IlayLa/OrbitOrange/pull/22), [#26](https://github.com/IlayLa/OrbitOrange/pull/26) |

### Removed (step H)
- `assets/placeholders/`: 29 generated part icons and 6 generated portraits.
- `tools/generate_placeholders.gd`.
- `scripts/mission/GeneratePortraits.gd`.

Nothing in the game referenced them any more. Older docs (`context/plan_draft.md`, `docs/ai_usage/T02.md`, `T04.md`, `tasks/CONTRACTS.md`) still mention them as history.

## Still placeholder or default

### Waiting on the artist
- **Tank drawing.** The tanks are a generated shape filled with the material swatch (see ¹ above).
- **Font punctuation.** `design/template.png` has letters, digits, θ, γ, Δ and $, but no punctuation. `tools/build_pixel_font.gd` draws 39 stand-ins:

  `. … , : ; ! ? ' ’ % ( ) [ ] / + - − – — _ = < > # & * · • × ✖ → ≈ ≥ ≤ ± ° ▲`

  A glyph drawn on the sheet replaces its stand-in when the font is rebuilt.
- **γ glyph.** The sheet's γ is now mapped correctly, but it is drawn like ϒ and should be redrawn.
- **One sprite for several parts.** The three radar tiers share a sprite, as do the top three Amit bands.
- **Small icons.** Some part icons read small at 20 px, for example the atmosphere probe and the imaging radar. The source art fills only part of its 64×64 canvas.

### Drawn by code, not by the artist
- **Glyphs, lamps and schematics:**
  - `scripts/ui/PixelGlyphs.gd`: inline icons such as $, clock and droplet.
  - `scripts/ui/LampBar.gd`: warning lamps.
  - `scripts/mission/OrbitSchematic.gd`: the orbit chart on mission select and the flight log.
  - `scripts/execution/RadarPanel.gd`.
  - `scripts/design/RocketStackPreview.gd`: the rocket stack blocks.
- **Earth in orbit planning.** It is a region cut out of the orbit mock-up (`scripts/orbit/OrbitView.gd`), not a sprite of its own.
- **Panels and cards** still build `StyleBoxFlat`s in code: `PartCard`, `ChoiceCard`, `MissionSelect`, `FinalScreen`, `PlanningConsole`, `RocketDesign`, `DataSourcesCodex`, `AlarmPanel`, `MissionPresentation` and `PlanningStyle`. The self-destruct button's red style is deliberate.
- **App icon.** `icon.svg` is still the Godot default.

### Follow-ups
- One shared card style (navy cards and white-framed boxes both exist), in place of the separate styles above.
- Mock-ups that are used directly as screen backgrounds (`planning_screen`, `construction_screen`, `orbit_screen`, `execution_screen`, `mission_choice`) are still loaded from `design/`. Only the final screen copies its backgrounds to `assets/art/`.
- The orbit chart's "e≈0" can still read as "ex0" at 1×.
