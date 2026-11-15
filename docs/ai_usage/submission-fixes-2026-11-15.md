# AI use for pre-submission fixes

- Date: 2026-11-15.
- Tool and model: OpenAI Codex, GPT-6, with Codex subagents.
- Request: apply review findings C-01, C-02, B-01, B-03 and B-04 to the latest local main. Keep the existing screens and leave the changes staged for team review.
- Changes: remove the private organiser email PDF and set the default layout direction in `project.godot`. Update the automatic flight's burn and launch-failure records in `autoload/FlightSimulation.gd` and the ascent model. Make automatic plan resolution respect the mission deadline. Add regression checks to `tests/test_automatic_planning.gd`.
- External resources: none added.
- Human review: the user selected the findings and set the scope. Review of the staged changes is pending.
