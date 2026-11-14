# OrbitOrange tasks

The game is split into eight tasks for four agents on four PCs. Each agent takes one lane and does its wave 1 task, then its wave 2 task.

| Lane | Wave 1 | Wave 2 |
|---|---|---|
| A · Orbit | [T01 Orbit mathematics](T01-orbit-mathematics.md) | [T05 Orbit planning screen](T05-orbit-planning-screen.md) |
| B · Rocket | [T02 Rocket model and parts](T02-rocket-model-and-parts.md) | [T06 Rocket design and planning overview](T06-rocket-design-and-planning-overview.md) |
| C · Flight | [T03 Flight simulation](T03-flight-simulation.md) | [T07 Events and emergency maneuver](T07-events-and-emergency-maneuver.md) |
| D · Mission | [T04 Missions, scoring, final screen](T04-missions-scoring-final-screen.md) | [T08 Execution console](T08-execution-console.md) |

[T09 Integration after wave 1](T09-integration-after-wave-1.md): the integrator's pass between the waves (end-to-end flight test, shared fixes, contracts up to date). Wave 2 starts when all four wave 1 branches and T09 are merged into `main`.

## What every agent reads first
1. [CONTRACTS.md](CONTRACTS.md): names, units, file ownership, what each module offers.
2. Its own task file.
3. The sections of `context/plan_draft.md` that the task file points to. That document is the design; where it and `CONTRACTS.md` differ, `CONTRACTS.md` wins.

## Rules for every task
- **Engine:** Godot 4.7.2-stable. Do not open the project with another version.
- **Touch only the files your task owns.** Everything else is someone else's, including `project.godot`. If you need a change elsewhere, follow "Changing a contract" in `CONTRACTS.md`.
- **Do not change the name, parameters or return type of an existing public function.** Other tasks are written against them.
- **Follow the naming rule** in `CONTRACTS.md`, section 1: full words, units in names, no abbreviations, no single-letter variables.
- **Remove the `STUB(T0N)` marker** from each body you replace. A search for `STUB(` then shows what is left in the whole project.
- **Write the three hand-back files** (`CONTRACTS.md`, section 9).

## Git
1. Start from the latest `main`: `git switch main`, `git pull`, `git switch -c task/T0N-short-name` (the branch name is in the task file).
2. Commit as often as you like on your branch.
3. Before the final commit, run the full check (below). It must end with "All checks passed."
4. Push the branch. The integrator merges it. Do not merge into `main` yourself and do not push to `main`.

## Checking your work
From the project folder, in Git Bash:
```bash
tools/check_project.sh
```
or in PowerShell:
```
tools\check_project.ps1
```
It imports the project, runs every test in `tests/`, and runs every scene in `scenes/` for 60 frames. Any error line fails the check. If Godot is not at `C:\dev\Godot\Godot_v4.7.2-stable_win64_console.exe`, set the environment variable `GODOT_EXECUTABLE` to its path.

To run only the tests:
```bash
"$GODOT_EXECUTABLE" --headless res://tests/TestRunner.tscn
```
To add tests, create `tests/test_<your_module>.gd`; `tests/test_skeleton.gd` shows the shape. The skeleton's own tests must keep passing.

A headless check cannot judge how a screen looks. Screen tasks (T04 to T08) also need a human to open the task's demo scene in the editor and look at it.

## For the integrator
- Merge wave 1 in any order; the four tasks own disjoint files. After each merge run the full check.
- After all four are in, start wave 2 from the new `main`.
- Collect contract requests from `tasks/notes/T0N.md` and apply them to the integrator-owned files.
- For the submission, assemble the AI-use statement from `docs/ai_usage/` and the reference list from `docs/references/`.
