---
name: unity-temporary-cache-path-is-tmpdir
description: "Where the embeddings cache actually lives on macOS: $TMPDIR/Tomato Cake/robotopia, not ~/Library/Caches"
metadata: 
  node_type: memory
  type: reference
  originSessionId: 83fb11f8-306a-4ed0-b774-01d68c630c2c
  modified: 2026-09-02T03:27:42.489Z
---

`PathUtil.CachePath` is `Application.temporaryCachePath`, which on macOS resolves under **`$TMPDIR`**
(`/var/folders/rj/…/T/Tomato Cake/robotopia/`) — *not* `~/Library/Caches`, despite the comment in
`PathUtil.cs` saying "`~/Library/Caches/…` on macOS". So the embeddings cache is
`$TMPDIR/Tomato Cake/robotopia/cached_embedding_<model-slug>.kv` plus a `.kv.lck`.

`PathUtil.persistentDataPath` is the different one: `~/Library/Application Support/Tomato Cake/robotopia`.
Fossils from before the cache moved still sit there (e.g. `cached_embedding_1-log.db`), and
`DeleteStaleCaches` only sweeps `CachePath`, so it will never clean them up.

**How to apply:** `find ~ -name 'cached_embedding_*'` misses it entirely. Search
`find /var/folders -maxdepth 6 -name 'cached_embedding_*'`, or just echo `$TMPDIR`.

Related: [[embeddings-store-immutable-open]].
