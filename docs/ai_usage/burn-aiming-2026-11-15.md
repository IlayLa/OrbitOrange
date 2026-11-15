# AI use: burn aiming on orbit planning and the emergency overlay (2026-11-15)

Pull request #37, opened and merged by Ilay. This entry was written afterwards from the pull request and its commits, which carry a `Co-Authored-By: Claude Opus 5.5` trailer.

- Date: 2026-11-15.
- Tool: Claude Code (Anthropic). Model: Claude Opus 5.5, as named in the commit trailers.
- Asked to: let the player aim a pulse while placing it (press on the path and pull back, slingshot style), add a typed burn-angle field, and use the same aiming on the emergency manoeuvre overlay.
- Produced or changed: `scripts/orbit/OrbitPlanning.gd`, `scripts/orbit/planning/PulseGeometry.gd`, `scripts/orbit/planning/PlanningStyle.gd`, `scripts/core/types/Pulse.gd`, `scripts/events/EmergencyOverlay.gd`, `scenes/events/EmergencyOverlay.tscn`, `scripts/events/EmergencyManeuver.gd`, `tests/test_orbit_planning.gd`, `tests/test_t05_scenarios.gd`.
- Images: none.
- Human direction and review: Ilay asked for the change and merged it. The pull request has no written GitHub review.
