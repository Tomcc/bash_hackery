---
name: embedding-current-model-not-public
description: "qwen3-embedding-0.6b is the client's CURRENT embedding model but not marked public:true in models.yaml — a latent player-facing break"
metadata: 
  node_type: memory
  type: project
  originSessionId: e94164d8-1b49-4e8a-9fb6-c45140edee9a
---

`Embedding.CURRENT = Qwen3Embedding0_6B` (Robotopia/Assets/Scripts/util/Embedding.cs) — the
client bakes AND queries embeddings with `qwen3-embedding-0.6b`. But in
cloud_api/common/src/models.yaml that model is NOT `public: true` (has a
`TODO(ROB-6423): confirm per-provider pricing before this model goes public`).

`ModelQuery::search()` returns `NoValidProviderFound` for non-public models unless the caller
is dev. **CI is dev** (GitHub org PAT → auth_github_endpoint grants "dev" scope), so CI
resolves it fine — this is NOT the cause of the CI Odin failures (see
[[embedding-failed-import-cached-empty]]).

**The real risk was PLAYERS:** real users authenticate non-dev, so every embedding request
(baking + runtime queries) would hit `NoValidProviderFound`. Tommaso flagged (2026-07-13) this
"almost broke all users on next release" — once the client requires qwen3, the model MUST be
`public: true`.

**FIXED 2026-07-13** (ROB-7205, commit 85e4e8f0a5): flipped to `public: true` + added
`test_client_current_embedding_model_is_public` (models.rs) guarding a non-dev query resolves.
Was a secondary fix, separate from ROB-7205's CI Odin failures
([[embedding-failed-import-cached-empty]]).

Verified live 2026-07-13 with a dev token: `POST /v1/agent/embeddings2` returns HTTP 200,
1048 bytes for qwen3 (20-byte header + 4 index + 1024 int8 = 1024-dim) and 1560 for the default
text-embedding-3-small (1536-dim). Backend serves qwen3 correctly today.
