# ServerSideMap x Hexium

Standalone automation for building and publishing an up-to-date Valheim 1.0-compatible build of [Mydayyy/Valheim-ServerSideMap](https://github.com/Mydayyy/Valheim-ServerSideMap).

This repository is independent from Vikinger Panel and contains only the ServerSideMap build/publish pipeline.

## What it does

- checks Mydayyy's `master` branch every 6 hours;
- tracks the exact upstream commit and plugin version;
- downloads the current public Valheim dedicated server assemblies;
- compiles the unmodified upstream ServerSideMap source with Roslyn;
- packages `ServerSideMap.dll` with the upstream MIT license and Hexium metadata;
- uploads the ZIP as a GitHub Actions artifact;
- publishes new versions to Hexium as `Sgorbi/ServerSideMap_Valheim1Fix` when `HEXIUM_TOKEN` is configured.

## Hexium versioning

Hexium package versions are tracked separately from the internal ServerSideMap plugin version.

The already-published compatibility build remains `1.3.14`. If Mydayyy pushes another commit while the plugin still reports `1.3.14`, the automation increments a same-upstream revision and publishes a newer valid Hexium version such as `1.3.14001`, then `1.3.14002`, and so on.

When the upstream patch changes, its patch number gets its own numeric range. For example, upstream `1.3.15` starts at Hexium package version `1.3.15000`. This keeps Hexium versions monotonic while preserving the exact upstream version, commit and compatibility-build revision inside the package README/changelog.

The automation allows up to 999 same-upstream revisions before requiring a versioning-policy change.

## Files

- `.github/workflows/sync-serversidemap.yml` — update/build/package/publish workflow.
- `scripts/build-serversidemap-1.0.sh` — reproducible ServerSideMap build against current Valheim.
- `scripts/package-serversidemap-hexium.py` — Hexium-compatible ZIP packager.
- `scripts/publish-serversidemap-hexium.py` — Hexium publisher.

The ServerSideMap source is not vendored or modified here. It is cloned from upstream at the pinned commit during the build.
