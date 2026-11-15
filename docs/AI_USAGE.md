# Use of AI in this project

The NASA Space Apps rules allow AI tools and require the submission to say how they were used. Most of this project's code is written by AI coding agents, directed and reviewed by the team.

To keep that record complete without several agents editing one file, **each task writes its own file** in `docs/ai_usage/`:

| File | Covers |
|---|---|
| `ai_usage/T00.md` | The design review, the plan, the shared skeleton, the contracts and the task files |
| `ai_usage/T01.md` … `T08.md` | One per task, written by the agent that does the task |
| `ai_usage/review-2026-11-15.md` | The code and design review of 15 November (the review itself is in `docs/review/`) |
| `ai_usage/submission-fixes-2026-11-15.md` | Fixes for review findings C-01, C-02, B-01, B-03 and B-04 |
| `ai_usage/D-02.md` | Review finding D-02: telemetry and debris damage |
| `ai_usage/assets-and-ui-2026-11-15.md` | Pull requests #8, #9 and #13 to #34: the team's art in the game, the pixel font, the button skin, readability and layout |
| `ai_usage/burn-aiming-2026-11-15.md` | Pull request #37: aiming burns on orbit planning and the emergency overlay |
| `ai_usage/submission-2026-11-15.md` | The web build, the README, this record and the licence, for the submission |

### In short
- **Code:** most of the game's code was written by AI coding agents (Claude Code with Claude Opus 5.5 and Claude Fable 5.2; OpenAI Codex), directed, tested and merged by the team. Each file above names the tool and model per session.
- **Images:** no image in the game was made by an image-generation model. The part sprites, Amit's portraits, the screen mock-ups, the logo, the font sheet and the button sheet were made by the team; AI-written scripts cut, scale and place them. The placeholder portraits that T04 generated in code were removed before submission.
- **Sound:** the game has no sound.

## What each file records
For every working session:
- the date,
- the tool and model,
- what it was asked to do,
- which files it produced or changed,
- what a team member reviewed, tested or changed by hand.

AI-made images, sounds and text are recorded the same way as code.

**A change made with AI is not finished until its entry is written, in the same commit.** The project page for the submission is assembled from these files.
