---
name: embeddings-v2-provider-quirks
description: ROB-6423 — v2 qwen3-embedding-0.6b stack (databricks/deepinfra/digitalocean) wiring, per-provider wire-format/normalization flags, and databricks' unstable latency
metadata:
  node_type: memory
  type: project
  originSessionId: 9acf4b2c-caef-45e1-984e-d39006d7b368
---

Shipped on tommo/embedding-batches (ROB-6423 + 6424, NOT yet merged, NOT yet deployed): the v2
embedding stack `qwen3-embedding-0.6b` (1024-dim), stack databricks → deepinfra → digitalocean.
Providers added to providers.yaml: `databricks` (AI Gateway URL
`https://dbc-05645a76-23a1.cloud.databricks.com/ai-gateway/mlflow/v1`, model id
`system.ai.qwen3-embedding-0-6b` — migrated 2026-07-11 off the deprecating `/serving-endpoints`
path; the same `databricks_key` works on both, response + latency identical), `digitalocean`
(`https://inference.do-ai.run/v1`). All three keys (`databricks_key`, `deepinfra_key`,
`digitalocean_key`) are in the `robotopia/llm-keys` secret. (No provisioned-throughput endpoint —
projected spend is ~$2/mo, so pay-per-token is fine.)

**Two portability fixes the prod embed path needed (each its own commit):**

1. **base64 isn't portable.** `openai::embed_with_provider` hardcoded `encoding_format:"base64"`.
   databricks & digitalocean IGNORE it and return JSON float arrays; only openai/azure/deepinfra
   honor base64. Added `supports_base64` (default false) to ModelInstance; `Data` is now
   float-native, `Base64Data`/`Base64EmbeddingsResponse` decode the compact form when the flag is
   set. The benchmark (tools/hammerbot/src/models/benchmark/embed.rs) already used `float` for this
   reason.

2. **Not all providers L2-normalize.** Measured live: databricks & deepinfra return unit vectors;
   **digitalocean returns raw vectors (L2 norm ~90)**. The int8 quantizer (write_embeddings) assumes
   unit length. Added `is_normalized` (default false → server normalizes via `normalize_l2` in
   run_model). Flags set: databricks/deepinfra `is_normalized:true`; DO omitted (normalized
   server-side). deepinfra `supports_base64:true`; databricks/DO off.

**databricks latency is UNSTABLE, not cold-start.** (My earlier cold-start theory was WRONG — the
endpoint is pay-per-token FOUNDATION_MODEL_API, shared always-on, no scale-to-zero config.)
Benchmarked ~130ms 2026-07-05 (ROB-6422). On 2026-07-10 it was stuck at ~12s for ~30min — proven
SERVER-SIDE by an EC2 probe on the LlmBenchmarkRunner role in us-west-2 (TCP connect 3ms, total
~12s, steady across 10 calls; NOT café wifi, NOT peering, NOT cold start). ~1h later it was back to
~0.3s. So databricks has multi-minute bad spells. Mitigation: `timeout_secs: 1` on the databricks
instance (same mechanism as groq's timeout) — rides the fast mode, falls through to deepinfra
during a bad spell instead of stalling. The databricks live test accepts EITHER a 1024-dim success
OR a timeout (slow-mode path), but fails on any wiring error (401/404/decode).

To measure a provider from prod's vantage point, launch a throwaway EC2 with the `LlmBenchmarkRunner`
instance profile (has SSM + secret read) and drive it via `aws ssm send-command`; pass scripts as
base64 to avoid newline mangling. See [[multi-provider-owns-retry]] for how fallthrough works.

**Model selection is by MODEL NAME, not a version int** (decided with the user): comparability is a
property of the weights, so the model name IS the compatibility contract. Request carries optional
`model` (absent = text-embedding-3-small default = rollback guarantee); endpoints use
`ModelQuery::require_type(Embedding)` so a wrong/unknown model 400s. Client (ROB-6424) has an
`EmbeddingModel` enum with permanent serialized int values + `Slug()`/`Dim()`; `Embedding.CURRENT`
= qwen3. The 4 embedding ScriptedImporters were version-bumped to force a repo-wide re-bake — baked
embeddings live in Unity's gitignored `Library/Artifacts`, NOT tracked `.asset` files, so there's
NO asset diff to commit; the version bump is the whole migration. Validated by running the game
against the local server (talked to a robot, worked).

**databricks latency was UNSTABLE (not cold-start) on 2026-07-10** — stuck ~12s server-side for
~30min (proven by EC2 probe), normally ~130ms. On the AI Gateway URL it's been steadily fast
(~0.17s). Kept `timeout_secs: 1` as a safety net regardless.

**Remaining before merge:** deploy the server (prod still runs pre-6423 lambda), and confirm
per-provider pricing (models.yaml values are placeholders). Runtime QPS is tiny (one-off queries);
the bake-time 429s were bake-only and handled by fallthrough.
