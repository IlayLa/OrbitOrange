# T05 feature scenarios

Open this worktree's project in Godot, open `scenes/development/T05_demo.tscn`, and press F6. Use the selector at the top to change scenarios, **Reset** to restore a fixture, and **Scenario guide** for its expected behavior. Every preset uses the existing part catalogue. These are editable planning examples; the failure and escape examples intentionally produce unsuitable flights.

From PowerShell in this worktree:

```powershell
.\tools\run_t05_scenarios.ps1
.\tools\run_t05_scenarios.ps1 -Scenario three-stage
```

| Preset / command ID | What to inspect |
| --- | --- |
| Free planning / `free` | Click the closed orbit to place a pulse. Drag the base and arrow, change delta-v, delete it, and change launch angle. |
| Edit a liquid pulse / `selected` | A selected 100 m/s pulse, orbital ghost, numeric magnitude, stage fuel and mass. Add a second pulse, then edit the first to recompute the later allocation. |
| Solid ascent + partial liquid / `three-stage` | Stage 1 is fully consumed and separated, stage 2 is partially consumed, stage 3 retains its full 1,500 kg. The stage rows and ascent tooltip expose consumption; new pulses use stage 2. |
| Fire a solid after ascent / `late-solid` | The solid in stage 3 survives ascent. Pulse 1 drains stage 2, then pulse 2 fires the whole solid. Select pulse 2 to see direction-only editing. The supplied retrograde direction predicts impact; steer it to compare the path. |
| Liquid-to-solid handover / `handover` | One pulse requests 10 m/s more than the remaining liquid capacity. It burns stage 2 then all of stage 3. The actual delivered kick overshoots and predicts escape. Reduce the demand to keep the solid unlit. |
| Ascent falls short / `impact` | A single small solid does not reach orbit. The predicted ascent ends at the atmosphere. |
| Demand exceeds fuel / `escape` | An excessive prograde request shows a shortfall while the actual delivered burn escapes. Reduce delta-v and inspect remaining reserve. |
| Unreachable downstream pulse / `unreachable` | Pulse 1 puts the craft into the atmosphere before pulse 2's angle. Pulse 2 consumes no fuel or mass. Edit pulse 1 to restore reachability. |
| Insufficient lift-off thrust / `no-liftoff` | A cold-gas thruster cannot lift the loaded rocket. The initial thrust gate blocks departure without spending fuel. |

Ascent and burns use the accepted instantaneous game model. Stage separation removes depleted dry hardware; it does not create propulsive delta-v. The mass readout shows mass after ascent or the selected pulse, while T06's shared mass chip remains launch wet/dry mass.

## Normal-game integration check

Run `scenes/development/T05_full_game_check.tscn`. This automated mouse-input scenario loads the normal Console, builds the example through its button, opens the orbit monitor, places a pulse, returns to the overview, reopens through **Plan flight**, and places another pulse. Run with `-- --animated-zoom` to include the normal T06 animation. It prints `T05_FLOW: all GUI checks passed` and exits on success.

## Automated coverage

`tests/test_t05_scenarios.gd` uses the same fixtures as the selector. It verifies their advertised outcomes, stage order, solid consumption, unreachable-pulse mass conservation, and automatic T07 emergency preview/live agreement. It also exercises the actual emergency overlay for liquid and solid starts and checks that a failed lower stage blocks upper-stage selection. Existing physics and editor regressions cover stage-separation mass, plan reassignment, and editing operations.

Run the complete project check before committing:

```powershell
.\tools\check_project.ps1
```

The standalone T07 conjunction scenario remains `scenes/development/T07_demo.tscn`, with its original event behavior preserved.
