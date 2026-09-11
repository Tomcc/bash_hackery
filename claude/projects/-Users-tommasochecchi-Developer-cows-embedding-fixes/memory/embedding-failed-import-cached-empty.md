---
name: embedding-failed-import-cached-empty
description: "Why lore/factmap \"no entries\" Odin errors persist across CI builds after an embeddings-endpoint outage, and the version-bump fix (ROB-7205)"
metadata: 
  node_type: memory
  type: project
  originSessionId: e94164d8-1b49-4e8a-9fb6-c45140edee9a
---

The lore/examples/lore_bank/factmap ScriptedImporters (`.lore.csv`, `.lore.md`,
`.examples.yaml`, `.lore_bank.yaml`) catch transient embedding failures
(`EmbeddingException` / retryable HTTP) and call `InitializeAsFailedImport()` with only a
`LogImportWarning` — baking an EMPTY-but-valid asset that Unity's ArtifactDB caches as a
successful import. Odin then flags "Lore asset has no parents or entries" / "Fact map asset
has no entries" on every subsequent build, because the source hash + importer version are
unchanged so Unity never re-runs the import — even once the backend is healthy again.

This bit us in the "New embeddings provider" rollout (ROB-6423/6424, commit a539c640da,
ci/2234): the `/agent/embeddings` endpoint briefly returned "Model Repository Error: No valid
provider found" 222× during the deploy window, baking ~130 empty lore + ~80 empty factmap
assets. ci/2235 had ZERO embedding errors but the IDENTICAL 130+80 Odin errors — proving the
importer didn't retry; it served the cached empty artifacts.

**Why:** Unity has no built-in way to make a ScriptedImporter retry a previously-failed import.
Deleting Library/Artifacts, touching the source, or reimporting the host asset all don't work
(content-hash + importer-version keyed). The only lever is bumping the importer's
`[ScriptedImporter(version, ...)]` number, which invalidates all cached artifacts of that type.

**How to apply:** ROB-7205 fix = bump all four importer versions by one (v27→28 lore.csv &
examples.yaml, v34→35 lore.md, v24→25 lore_bank.yaml). Root-cause fix (not retrying / caching
a transient failure as success) is a Unity ArtifactDB rabbit hole Tommaso explicitly declined.
Related: [[embedding-current-model-not-public]], and the fix-odin-spurious-errors skill (same
mechanism, but that skill is for LOCAL-only stale artifacts that pass on CI).
