# Minimize text walls: three agreed design options

This document comes out of a designer–player review exchange (three rounds) that agreed on how to remove text walls from the game. Nothing in the game has been implemented yet.

## Text walls found (worst first)
| # | Where | Problem |
|---|---|---|
| A | Mission Select details monitor (`scripts/mission/MissionSelect.gd:52-98`) | About 200 words over 2-3 scroll pages. Durations are raw seconds ("16635 seconds"). The 5/15/30 quest penalty rule is repeated under every quest. Instrument fit is written out as "2/3 stars". |
| B | Final Screen (`scripts/mission/FinalScreen.gd:67,81,89,93`, `scripts/mission/Scoring.gd:36-98`) | 11 score rows at 4 decimal places, each with a sentence; the headline score is also at 4 decimals; each event takes 3 lines. |
| C | Part details popup (`scripts/design/PartDetailsPopup.gd:65-115`) | A "Label: value unit" stat dump in 7-8 px text, up to half the screen tall. Source citations run to about 380 characters. |
| D | Planning Console bezel (`scripts/design/PlanningConsole.gd:371-381`, `scripts/rocket/RocketModel.gd:218-260`) | 3-6 warning sentences, some duplicated, not attached to the stage or pulse they refer to. |
| E | Rocket Design hint (`scripts/design/RocketDesign.gd:36-41,274-282`) | Tutorial prose that is always on screen. |
| F | Execution console (`scripts/execution/ExecutionConsole.gd:149`) | A plain-text stub, due to be replaced in T08 (a guardrail only). |
| G | `data/missions.json`, `data/event_types.json` | "Placeholder:" descriptions. The layout must cap their length. |

## Pre-step (size S, ships first): number formatting
Add one static helper, `scripts/core/NumberFormat.gd` (it needs a `CONTRACTS.md` entry):
- `money(12.5)` → "$12.5M"
- `duration(16635)` → "4h37m"
- `points()`: whole numbers for totals, at most 1 decimal for rows
- `km`, `mps`

This fixes `FinalScreen.gd:67`, `MissionSelect.gd:56/82/96` and the strings in `Scoring.gd` without needing any of the options below.

## Option 1: Instrument Panel (build and plan loop)
**Fixes C, D, E.**
- **Stat chips:** each stat shows a glyph, a number and a unit, for example "▲ 47kN". Never a glyph alone.
- **Delta arrows:** compare against the part installed in the same slot: the selected stage for engines and tanks, the payload for telemetry and science. The arrow shows the direction the number moved (▲ higher, ▼ lower) and its colour shows the effect for the player (green better, red worse), judged per stat (lower is better for cost, dry mass, noise and dropout). For example, a pricier part is a red ▲ on "$9M", a lighter part a green ▼ on the mass, and less power a red ▼. An empty slot shows no arrows.
- **Popup:**
  - about 130 px wide, nothing smaller than 8 px (this retires the 7 px source font)
  - a 1-line short source tag that is always visible, with the full citation behind (i)
  - the tradeoff shown as +/- pictograms
- **Warning lamps:** 7×7 pixel lamps that differ by shape as well as colour: ✖ red for blocking, ▲ amber for a warning, ● green for OK.
  - They sit on each stage block in `RocketStackPreview` and on each pulse marker.
  - The bezel shows a summary such as "✖1 ▲2".
  - Hovering a lamp shows its sentence. Clicking pins it, and Tab cycles focus between lamps.
- **Legend strip:** one 8 px row under the part-list tabs showing the active category's glyphs and their names. After the first part is installed it collapses to a "?" that brings it back. This replaces the hint label.
- **Contract:** warnings get optional, additive fields `code`, `target_stage_id`/`pulse_index` and `severity`. Until then, duplicate warnings are removed on the screen side, in `PlanningConsole._message_text`.

```
[icon] STAR 48           $2M
 ⚡286s▲  ▲67kN▼  ⛽2011kg  ⚖124kg
 + cheap   - no restart
 src: Northrop Grumman      (i)
```
Files: `PartDetailsPopup.gd`, `PartCard.gd`, `PlanningConsole.gd`, `RocketStackPreview.gd`, `RocketDesign.gd`, new `assets/ui/icons/*.png`. Cost: M.

## Option 2: Orbit Schematic (geography and outcome)
**Fixes A (target and hazards), B (orbit rows), G.**
- **Mission Select diagram:** a mini `OrbitView` that shows:
  - the body
  - the target ring with its tolerance halo
  - the science band, in solid low-alpha blue
  - the hazard belt, as a 2×2 red/black checker dither (hatching aliases at 1×)
  - budget and duration as chips beside it
- **Honest geometry:**
  - The ellipse is drawn at its true shape, with an "e≈0" tag when e ≤ 0.05.
  - Altitude may be stretched only if the diagram says so: an 8 px "ALT not to scale" (or "ALT ×N") tag, with the ticks showing real km values.
  - Halos and bands are at least 2 px wide.
  - Ticks come from `mission.display.altitude_ring_kilometers` and are laid out left-to-right even in RTL locales.
- **Final Screen overlay:** the target ring as a green dashed line, the achieved orbit as a solid white line (not orange, which would sit on the red hazard checker), and the miss labelled with its own gap glyph and the difference, for example "+42 km", plus "in tol." or "off tol." in words.

```
+--MISSIONS--+ +----------------------------------+
| First orbit| |  .-~~~-.  ┊400km  ALT not to scale|
|  $30M  ●●○ | | ( EARTH )  ◎ target ±100  e≈0   |
| Higher...  | |  '-~~~-'   ░ science  ▚ debris  |
+------------+ | $30M   4h37m                     |
               +----------------------------------+
```
Files: `MissionSelect.gd`, `MissionPresentation.gd`, `FinalScreen.gd`, reusing `OrbitView.gd`. Cost: M.

## Option 3: Cards & Bars (the opening and closing screens)
**Fixes A (science and quests), B (score and events), the meta-text, and G.**
- **Mission Select columns:**
  - Three always-visible columns of about 200 px each: MISSION | SCIENCE | QUESTS.
  - A live budget footer sits next to Accept.
  - No hidden wizard.
- **Cards:**
  - At most 2 lines of text (about 80 characters, with an ellipsis enforced by the layout) plus chips.
  - Instrument fit is shown as ★ pips.
  - Science choices that can't be picked are greyed out with a lock icon.
- **Quest penalties:**
  - The 5/15/30 penalty escalation is shown once, as pips in the QUESTS header. The header stays on screen whenever quest cards are visible.
  - The pips light up as quests are ticked, so the player can see what each extra quest risks.
  - Each card shows "+$5M / −grant" and a risk chip.
- **Final Screen:**
  - A whole-number total.
  - An earned/lost bar per scoring group, each with a 2-3 word tag (for example "ecc. off −2"). Clicking a bar opens its full sentence.
  - An event timeline strip with pips you can hover.
- **Meta-text:** a grey 8 px PLACEHOLDER badge replaces "(placeholder rates)" and the event-log disclaimer.
- **Data Sources codex:** reachable from the Main Menu and from the popup's (i).

```
[portrait] GREAT SUCCESS   82 pts
ORBIT   ████████▒▒  16/20  ecc. off −2
BUDGET  ██████████  10/10
SCIENCE ██████▒▒▒▒  24/40  1 obj missed
QUESTS  ██▒▒        −5     grant lost
0s |--●-----●------| 4h37m
```
Files: `MissionSelect.gd`, `FinalScreen.gd`, `MissionPresentation.gd`, `MainMenu`. Cost: M-L.

## Shared rules
- Use only the existing `ScreenLayout` colours, plus one amber for warnings if it is missing.
- Nothing smaller than 8 px. Glyphs sit on the integer pixel grid with a 1 px dark outline.
- Colour is never the only signal: shape carries the meaning too.
- Every glyph and pattern must be tested at 1× on the 640×400 canvas.

The options combine: Option 1 covers the build and plan loop, Option 2 the geography, and Option 3 the opening and closing screens. Each can also ship on its own.
