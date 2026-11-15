# Plan: `implement-our-assets` — swap placeholder art for our own

## Context
The game still draws generated placeholders (`assets/placeholders/parts/*.png` 16×16 via `icon_path` in `data/parts.json`, `assets/placeholders/portraits/*.png` 32×32 in `scripts/mission/FinalScreen.gd`, made by `tools/generate_placeholders.gd` / `scripts/mission/GeneratePortraits.gd`) and Godot's default font and buttons. The 2026-11-15 review on `main` lists this as **B-13** ("committed team art is unused") and **I-13** (no pixel font).

Main was updated (`06453f6..3692f29`): commit `26b3a52` added the missing telemetry and science sprites, so **every category now has art**:

| Art (in `design/` on main) | Files | Size |
|---|---|---|
| Engines | `construction/engines/engine_{coldgas,star37,star48,rutherford,merlin,orion,RL10}.png` | 64×64 |
| Tank materials | `construction/materials/materials_{aluminum,Al-Li,carbon}.png` | 64×64 |
| Telemetry | `construction/telemetry/tele_{altmeter,betteraltmeter,sunsensor,startracker,fuel,temperature,radar,computer,bettercomputer}.png` | 64×64 |
| Science | `construction/science/science_{camera,bettercamera,magnetometer,atmoprobe,radar}.png` | 64×64 |
| Amit | `amit sprites/amit_{concerned,explaining,happy,judging,greatsuccess}.png` | 128×80 |
| Button skin | `buttons.png` (normal / pressed / green-frame states) | 64×64 |
| Pixel font | `template.png` (0-9, A-Z, a-z, punctuation, °) | 64×64 |

## Groundwork (already on `implement-our-assets`)
- Run-time art goes under `assets/art/`; `design/` stays source art (review "Direction"; also avoids the space in `design/amit sprites`). Folders `assets/art/parts/{engines,tanks,telemetry,science}` and `assets/art/portraits` exist; copy PNGs in with game-id file names (e.g. `assets/art/parts/engines/engine_cold_gas.png`) and delete the folder's `.gitkeep`.
- `assets/ui/ui_theme.tres` (empty `Theme`) is wired as `gui/theme/custom` in `project.godot`. Sub-branch F fills it; G adds `gui/theme/custom_font`.
- Pixel art keeps nearest filtering (`default_texture_filter=0`).

## Rules for every sub-branch
- Branch from `implement-our-assets`, open the PR into `implement-our-assets` (not `main`).
- Touch only the files/lines your section names. In `data/parts.json` edit only your category's `icon_path` lines.
- Run the verification section below before opening the PR, and list in the PR anything you kept as placeholder/default.

## Sub-branches (from `implement-our-assets`, run in parallel)
Each owns disjoint files, or disjoint line ranges of `data/parts.json` (engines ~1-130, tanks ~132-230, telemetry ~234-460, science ~465-560 — only their `icon_path` lines), so merges are clean. Each A–D branch checks the 64×64 art at 20px in `PartCard.gd` (`ICON_SIZE_PIXELS`), `PartDetailsPopup.gd` and `RocketStackPreview.gd` (~line 385), and keeps `tests/test_rocket_model.gd:365` (icon files exist) passing.

### A. `assets/engines` — 7 icons
`engine_cold_gas←coldgas`, `engine_solid_kick←star37`, `engine_solid_basic←star48`, `engine_liquid_small←rutherford`, `engine_liquid_basic←merlin`, `engine_solid_booster←orion`, `engine_liquid_hydrogen←RL10`.

### B. `assets/tanks` — 6 icons from 3 materials
`tank_aluminium_*←materials_aluminum`, `tank_aluminium_lithium_*←materials_Al-Li`, `tank_composite_*←materials_carbon`; regulated and blowdown share the material image.

### C. `assets/telemetry` — 11 icons from 9 sprites
`altimeter_basic←tele_altmeter`, `altimeter_precise←tele_betteraltmeter`, `attitude_sun_sensor←tele_sunsensor`, `attitude_star_tracker←tele_startracker`, `fuel_gauge←tele_fuel`, `temperature_sensor←tele_temperature`, `computer_basic←tele_computer`, `computer_hardened←tele_bettercomputer`, `radar_{basic,standard,advanced}←tele_radar` (one sprite for three tiers; note in PR).

### D. `assets/science` — 5 icons
`camera_basic←science_camera`, `camera_high_resolution←science_bettercamera`, `magnetometer←science_magnetometer`, `atmosphere_probe←science_atmoprobe`, `imaging_radar←science_radar`.

### E. `assets/amit-portraits` — final-screen portraits
- `PORTRAIT_PATHS` in `scripts/mission/FinalScreen.gd`: Failure→`amit_concerned`, Partial Success→`amit_judging`, Success→`amit_happy`, Great Success→`amit_greatsuccess`, **Perfect→`amit_greatsuccess` with a speech bubble "I Like It - Perfect"**, Scientific Breakthrough→`amit_explaining`.
- Amit fills a small part of the 128×80 frame; crop with `AtlasTexture` into the 72×72 portrait rect (or enlarge it). Bubble = small panel + label beside the face, Perfect only.
- Test in `tests/test_scoring.gd`: Perfect shows the bubble text, other bands don't.

### F. `assets/button-skin` — `design/buttons.png`
- Slice into `StyleBoxTexture`s (normal, hover, pressed, focus = green frame) in `assets/ui/ui_theme.tres` under `Button`.
- Fold button styles out of the two theme factories (`MissionPresentation.create_theme`, `PlanningStyle.create_theme`) and per-script `StyleBoxFlat` button overrides (`PlanningConsole.gd`, `RocketDesign.gd`, `AlarmPanel.gd`, `ClockPanel.gd`, `ChoiceCard.gd`, `MissionSelect.gd`, `OrbitPlanning.gd`) so the theme shows. Keep deliberate ones (red self-destruct) and list them in the PR. Does not touch `project.godot`.

### G. `assets/pixel-font` — `design/template.png`
- Build `assets/ui/pixel_font.tres`; if the sheet isn't a uniform grid, add `tools/build_pixel_font.gd` mapping glyph rects to characters (keep it for rebuilds).
- Set `gui/theme/custom_font` in `project.godot` (a different line than step 0's). Don't change font-size literals; list overflowing screens as a follow-up.

### H. `assets/remove-placeholders` — last, after A–E merge
Delete `assets/placeholders/`, `tools/generate_placeholders.gd`, `scripts/mission/GeneratePortraits.gd`; fix leftover references. (Now unblocked, since telemetry/science art exists.)

### Dependencies
A–G are independent and run at once. H waits for A–E. F and G touch different files; either can merge first.

## How the sub-branches run
 one session per sub-branch A–G, each in its own worktree from `origin/implement-our-assets`, brief = its section above, each opens a PR into `implement-our-assets` (not `main`). H is started once A–E are merged.

## Final report (last step, on `implement-our-assets` after the merges)
Write `docs/ASSET_SWAP_REPORT.md` and commit it to `implement-our-assets`. Build it from the merged tree, not from the sessions' notes:
- **Swapped**: one table per category (parts by id, portraits by band, buttons, font): game id / screen → new file under `assets/art/` or `assets/ui/` → source file in `design/` → sub-branch / PR link. Mark shared sprites (3 radar tiers, regulated/blowdown tanks, Great Success/Perfect Amit).
- **Still placeholder or default**: every remaining reference found by `grep -rn "assets/placeholders"` plus art not covered by this plan: procedurally drawn UI (`PixelGlyphs.gd`, `LampBar.gd`, `OrbitSchematic.gd`, `RadarPanel.gd`, the `_draw` code in `OrbitView.gd`, the Earth sprite cut from the orbit mock-up), the mock-up backgrounds used as screens, `icon.svg`, unmerged sub-branches, and controls that keep a deliberate `StyleBoxFlat` or default font.
- **Follow-ups**: overflowing text after the font swap, the unused `amit_explaining` spots the review suggests (mission select), and anything a sub-branch PR flagged.
Also post the report's summary as the PR description when `implement-our-assets` is opened against `main`.

## Verification (each sub-branch, then the base branch after merging)
- `GODOT_EXECUTABLE=/c/Users/gotya/Downloads/Godot_v4.7.2-stable_win64.exe/Godot_v4.7.2-stable_win64_console.exe tools/check_project.sh`; `tests/TestRunner.tscn` under `timeout` (hangs on parse errors).
- `grep -r "assets/placeholders"` lists only categories not done yet (nothing after H).
- Visual: run windowed with `--language en` (screens are blank here without it) and capture the rocket design screen (A–D), the final screen per band incl. the Perfect bubble (E), and screens with buttons/text (F, G). A human looks at E (review asks for this).
