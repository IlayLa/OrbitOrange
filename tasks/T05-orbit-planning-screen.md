# T05 · Orbit planning screen (revised)

User-approved revision: 2026-11-15. Branch: task/T05-orbit-planning-screen.

Read tasks/README.md and tasks/CONTRACTS.md, including the automatic-planning revision.

## Goal

Show calculated automatic ascent into the mission's first closed orbit, then let the player place, move, steer, size and delete pulses. Stage assignment follows fuel consumption automatically.

## Scope and integration

The agreed plan includes shared ascent/staging prerequisites in the resolver, shared types, flight simulation and reference setup, followed by the T05-owned screen. Exact changes and cross-task handoffs are listed in tasks/notes/T05.md.

Keep OrbitView's seven existing public functions. Keep the stat-chip, back-button and console-switch areas for their owners. Do not implement T06 zoom or T07 emergency UI.

## Required behaviour

- Use Amit's supplied planning/orbit drawings directly. Preserve their frames, monitor rectangles, and pixel artwork; controls overlay the existing screens/bezel.
- The normal full-game overview must open the interactive editor through the orbit monitor or Plan flight; provide Back/Esc.

- Automatic departure/coast/insertion targets the mission altitude; check initial thrust against weight.
- Consume stages sequentially: full solids, partial liquids, separation at depletion, no silent discard of useful lower stages.
- Continue a liquid demand across stage boundaries. A following solid burns fully only if demand remains; show actual overshoot.
- Show read-only engine rows: name/type, ascent fuel used in kg/percent, fuel left after ascent, and delta-v reserve after reachable pulses.
- Retain the 0–89-degree launch-angle slider, default 30 degrees.
- Draw mission body/rings/launch/science/hazard zones, trajectory colours, apsides, craft and revealed threats using the shared display mapping.
- Draw IMPACT/ESCAPE paths and their established warnings in red; mark unreachable pulses separately.
- Place pulses by clicking the path, with no engine picker. New pulses use the first subsequent polar-angle crossing and zero extra revolutions.
- Beginning on a solid gives a direction-only full-motor pulse. Liquid requests have arrow and slider/numeric magnitude editing.
- Drag anchors/arrows, right-click or press Delete to remove; show before/after ghosts only for the selected pulse and a fixed drag-start path.
- Recompute downstream fuel/stage assignments and notify at most once per frame.
- Show orbit readouts, reserve, and mass after ascent/selected pulse. Burn-marker tooltips list each contributing stage.
- Fully used/dropped stages cannot supply future pulses. Unreachable pulses burn no fuel.

## Model assumptions

Liquid engines are restartable without limits. All manoeuvres are instantaneous, including multi-stage pulses. Fixed launch losses, spherical two-body dynamics and the atmosphere cutoff are deliberate game assumptions. No climb-time manual pulse editor or early-jettison control is included.

## Acceptance

- Run res://scenes/development/T05_demo.tscn.
- Confirm automatic insertion, partial upper-stage fuel, live pulse changes, ghosts, deletion, and impact/escape warnings.
- Run tools/check_project.ps1 (or .sh) with Godot 4.7.2; require All checks passed.
- Tests cover mixed-stage allocation, mass conservation, reachability, prediction/execution agreement, and editor interactions.
- Remove T05 skeleton markers and supply AI usage, references, and task notes.
- Record human play-through acceptance separately from automated tests and agent screenshot review.
