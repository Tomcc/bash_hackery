---
name: handoff-from-monorepo-session
description: "Where this project came from and what was left pending at the 2026-09-06 handoff"
metadata:
  type: project
---

The project was built in a session running from the Robotopia monorepo; its full transcript is at
`~/.claude/projects/-Users-tommasochecchi-Developer-cows-tommo-treasure-hunt/e1af8455-2844-48a3-940e-b2e43aad2356.jsonl`
(this machine only). Everything durable was moved into the repo itself — CLAUDE.md, skills,
QUESTIONS.md, facts/.

Left pending at handoff:
- **Chapter summaries not yet run.** Prompt ready at `prompts/chapter-summaries.md`. Plan: ONE
  agent reads the whole book raw (~330k tokens of HTML) and writes ~30 summary facts with
  `pages:` frontmatter. Needs the 400k context cap lifted for that one run:
  `CLAUDE_CODE_AUTO_COMPACT_WINDOW=1000000 claude -p "$(cat prompts/chapter-summaries.md)" --model opus`
  from the repo root. If it works, record the technique in CLAUDE.md (user asked for this).
- The treasure folder may not be trusted yet in `~/.claude.json` (settings.json permissions
  ignored until the trust dialog is accepted interactively).
- New photos needed from the user: 042, 043, 049, front cover with jacket (QUESTIONS.md).
- The user reviews extracted pages in the viewer and reports rounds of fixes; round 1 is done
  (themed Opus fixers), round 2 feedback will come the same way.
