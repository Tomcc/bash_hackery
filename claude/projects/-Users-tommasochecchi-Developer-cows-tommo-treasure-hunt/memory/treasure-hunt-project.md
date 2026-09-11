---
name: treasure-hunt-project
description: "The treasure book transcription lives at ~/Developer/treasure, not in this monorepo"
metadata: 
  node_type: memory
  type: project
  originSessionId: e1af8455-2844-48a3-940e-b2e43aad2356
  modified: 2026-09-06T13:11:41.035Z
---

The "There's Treasure Inside" book transcription project is a separate local git repo at
`~/Developer/treasure` (no remote), even though sessions run from the Robotopia monorepo checkout.
Photos in `pages/` (filename = page number, 90 skipped), extracted HTML in `extracted/`, agent spec
in `prompts/extract-page.md`, tools `scripts/clip.py` (percent crop) and `scripts/shot.py`
(headless-Chrome render).

As of 2026-09-06: pure HTML+CSS system landed. Extraction agents pick a page *kind* and imitate a
finished reference page: 116 chapter-opener, 031 text (wrapped inset), 062 full-page-image, 165
image-only, 153 paper-tear; 191 is the worked example for vertical-rhythm anomalies. Body leading
calibrated on page 31 (line-height 1.25). **Use Sonnet for extractions, not Haiku** — Haiku failed
all five test pages (hallucinated layouts, cropped the facing page, silently corrected "Mohave");
Sonnet passed all four retries. A stash "fired session WIP" holds the old JS-era uncommitted work.
See [[no-preprocessing-let-reader-agent-iterate]].

2026-09-06 overnight: swarm extracted ALL 255 pages (23 Sonnet batch agents + 1 Opus for custom
pages, zero errors, ~2.7M subagent tokens). Backed up to private GitHub repo Tomcc/treasure.
Viewers: reader.html (facing spreads), review.html (page vs photo). QUESTIONS.md queues the next
jobs: hunt-rules sweep, geo-oracle CLI, red-break audit, page-123 letter. Content unreviewed by
the user — they review via review.html. User will only physically hunt near WA/Seattle.
