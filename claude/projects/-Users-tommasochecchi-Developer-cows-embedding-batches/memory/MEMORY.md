# Memory index

- [multi_provider owns retry](multi-provider-owns-retry.md) — endpoint handlers must not add their own provider retry loops; exponential_backoff returns a Duration and doesn't sleep
- [embeddings v2 provider quirks](embeddings-v2-provider-quirks.md) — ROB-6423 spike: v2 providers wired but need base64→float + normalization fixes; databricks cold-start ~20s
- [open Unity in a CoW workspace](open-unity-in-cow-workspace.md) — `open scene.unity` hits Hub + license popup; launch the editor binary directly with -projectPath instead
