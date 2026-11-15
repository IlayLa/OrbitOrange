# AI use: submission readiness (2026-11-15)

- Date: 2026-11-15.
- Tool: Claude Code (Anthropic), desktop app, with shell, Godot 4.7.2, the GitHub CLI and its built-in browser. Model: Claude Opus 5.5.
- Asked by Yasha to: compare the repository with the NASA Space Apps submission guide and the Tel Aviv submission slides and list what is missing; then add a web build, and bring the README, this record of AI use and the licence up to date.

## Web build (pull request #38)

- Produced: `export_presets.cfg` (a Web preset without threads, since GitHub Pages cannot send the headers a threaded build needs), `.github/workflows/web-build.yml` (installs Godot 4.7.2 and its export templates from the official release, exports the game and publishes it on GitHub Pages), one line in `.gitignore`.
- Validation: the workflow's build passed on the pull request. The agent downloaded that build, served it locally and played one mission in a browser from the main menu to the final screen, including a random event; the browser console showed no errors.

## README, AI record and licence (this pull request)

- Produced: `README.md` rewritten for judges and players, with the developer instructions kept below; `docs/screenshots/readme/` (four screens captured from the game with `tests/playtest/CaptureScreens.tscn`); `LICENSE` (the Apache License 2.0 text, the licence the NASA Space Apps terms apply when a team chooses none); `docs/ai_usage/assets-and-ui-2026-11-15.md` and `docs/ai_usage/burn-aiming-2026-11-15.md`, written afterwards from the pull requests and commits; this file; the table in `docs/AI_USAGE.md`; a note in `docs/ai_usage/T04.md` that its generated portraits were later removed.
- Images: none.
- Human review: pending, by Yasha before merging.
