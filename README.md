# OrbitOrange

A space mission design game for the NASA Space Apps Challenge 2026 ("Space Mission Design Game"). The player picks a mission, builds a rocket from real-world parts under a budget, plans the launch and the engine pulses on a Keplerian orbit, then flies the mission from a control room and is scored on the result.

Two-dimensional, pixel art, built with Godot. This is a proof of concept.

## Open the project
1. Install **Godot 4.7.2-stable** (the standard build, not the .NET one). Everyone must use this exact version: a newer editor rewrites project files and breaks the others.
2. Clone this repository.
3. Start Godot → **Import** → choose `project.godot` in the cloned folder → **Import & Edit**.
4. Press **F5** to run. The first open takes a moment while Godot builds its cache in `.godot/` (that folder is not committed).

The repository folder is the Godot project; there is nothing else to set up.

## Where things are
| Folder | What is in it |
|---|---|
| `tasks/` | The work, split into eight tasks, and `CONTRACTS.md`, which fixes names, units and who owns which file. **Start here.** |
| `context/` | The challenge description, the hackathon rules, the team's notes and `plan_draft.md`, the full design. |
| `design/` | Screen mock-ups and the logo. The game canvas is 640×400, five times the 128×80 mock-ups. |
| `autoload/` | Nodes that exist for the whole game: the catalogue, the game state, the flight, the events. |
| `scripts/` | Game code, by module: `core`, `orbit`, `rocket`, `flight`, `mission`, `design`, `execution`, `events`, `screens`. |
| `scenes/` | One scene per screen. |
| `data/` | The catalogue as JSON: parts, missions, celestial bodies, event types. Adding a mission or a part means adding an entry here. |
| `tests/` | Automatic tests. |
| `tools/` | The project check and the placeholder-art generator. |
| `docs/` | The record of AI use and of every external resource, required by the hackathon rules. |

## Check the project
Run this before every commit. It imports the project, runs every test and runs every scene for a moment.

Git Bash:
```bash
tools/check_project.sh
```
PowerShell:
```
tools\check_project.ps1
```
If Godot is not at `C:\dev\Godot\Godot_v4.7.2-stable_win64_console.exe`, set the environment variable `GODOT_EXECUTABLE` to the path of your Godot console executable.

## Working on it
Read [tasks/README.md](tasks/README.md). In short: one branch per task, edit only the files your task owns, keep the names readable (full words, units written out), and run the check before you push.

## Current state
The project is a **walking skeleton**: it runs from the main menu to the final score, but most modules are placeholders marked `STUB(T0N)` in the code, waiting for task T0N. A search for `STUB(` shows what is not built yet.

## Licence
No licence has been chosen yet. Under the NASA Space Apps terms, a submission without one is distributed under Apache 2.0.
