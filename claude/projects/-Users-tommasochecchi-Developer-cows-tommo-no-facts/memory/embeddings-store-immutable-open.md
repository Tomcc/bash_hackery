---
name: embeddings-store-immutable-open
description: "Why EmbeddingsCache has an `immutable` open flag that skips locking entirely"
metadata: 
  node_type: memory
  type: project
  originSessionId: 47b9ee99-e00e-41b1-9c85-947da6e3b18b
  modified: 2026-08-27T09:46:50.237Z
---

`EmbeddingsCache.OpenAsync(immutable: true)` opens a store for reading with **no lock file** and no
writes at all — not even the timestamp a Get renews. The flag is the caller asserting the file
cannot change while open; that assertion is what makes skipping the lock correct. The lock for a
normal open stays a plain `path + ".lck"` sibling.

**Why:** the baked embedding cache ships inside the signed app bundle, where nothing may be written
next to the data. Two rejected designs (2026-08-27), both mine, both flagged by Tommo:
1. A read-only open that silently ignored other writers' locks — a footgun, since nothing stopped a
   caller pointing it at the live runtime cache.
2. Moving the lock to the OS temp dir keyed by flattened path. Works, but pointless once `immutable`
   exists: an immutable store has no writer to exclude, so it needs no lock at all.

There is no requirement to share a store between processes.

**How to apply:** `immutable: true` is only for media nothing can write. It must open the data file
`FileAccess.Read` — a read-write open of a read-only *file* throws `UnauthorizedAccessException`,
which is exactly what a signed bundle ships. `AbsorbMissingFrom` requires an immutable source, which
also makes self-merge impossible (it deadlocked on its own lock before that rule).
