# Minimize text walls: notes

Implements all three options of `design/minimize_text_walls_options.md` and its number-formatting pre-step, on branch `minimize-text-walls`.

## Done
- `scripts/core/NumberFormat.gd`: short number texts. `Scoring.gd` explanations, the Mission Select screen, the Final Screen, the part cards and the popup use it.
- Option 1 (Instrument Panel): `PartDetailsPopup.gd` is a 130 pixel instrument panel (glyph chips, better/worse arrows against the part in the same slot, fit stars, +/- trade-off, one-line source tag with (i)); `PartCard.gd` shows a glyph chip and opens the codex on right-click; `RocketStackPreview.gd` draws a 7×7 lamp per stage (and one for the whole rocket), hover shows the sentence, click pins it, Tab steps through; `PlanningConsole.gd` has a lamp bar with the "✖1 ▲2" summary and one message line; `RocketDesign.gd` replaces the hint prose with a glyph legend that collapses to "?" after the first part, and a short amber message when a click is refused.
- Option 2 (Orbit Schematic): `scripts/mission/OrbitSchematic.gd` (extends `OrbitView`), used on Mission Select and, with the achieved orbit and the miss in km, on the Final Screen.
- Option 3 (Cards & Bars): `MissionSelect.gd` is three columns of `ChoiceCard`s with the penalty pips and a live budget footer; `FinalScreen.gd` shows the whole-number total, earned/lost bars with 2-3 word tags (click: the full Scoring sentences), an event timeline with hover pips, and the orbit overlay. Data Sources codex (`scripts/ui/DataSourcesCodex.gd`) from the Main Menu and from a part card.

## Contract requests
1. Register `scripts/core/NumberFormat.gd` and the new `scripts/ui/**` module (done in `CONTRACTS.md` §2 and §5, to be confirmed by the integrator).
2. No change to `PlanSummary`: warnings stay sentences and lamps are found on the screen side (`WarningLamps`, from "Stage N" / "Pulse N" in the sentence). If the team prefers explicit fields, the optional additive fields `code`, `target_stage_id`, `pulse_index`, `severity` are still the proposal; nothing here depends on them.
3. `MainMenu.gd` (integrator-owned) gained a "Data sources" button.

## Not done / deviations
- Pulse markers do not exist yet (`OrbitPlanning.gd` is a T05 stub), so pulse lamps are shown in the planning bezel (e.g. "▲P2") instead of on the markers. `WarningLamps.worst_severity_for_pulse` is ready for T05.
- The legend is a short column in the free cell under the tabs, not one row: the cell is 105 pixels wide.
- The popup's (i) is opened by right-clicking the card: the popup follows the hover and cannot take a click.
- `PartCard.key_number_text` became `PartCard.key_chip` (glyph and text); `PartCard.cost_text` returns "$1M". Tests updated.
- Screens are captured by `tests/playtest/CaptureScreens.tscn` (run with `--language en`, windowed).
