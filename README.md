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

## Files

- `.github/workflows/sync-serversidemap.yml` — update/build/package/publish workflow.
- `scripts/build-serversidemap-1.0.sh` — reproducible ServerSideMap build against current Valheim.
- `scripts/package-serversidemap-hexium.py` — Hexium-compatible ZIP packager.
- `scripts/publish-serversidemap-hexium.py` — Hexium publisher.

The ServerSideMap source is not vendored or modified here. It is cloned from upstream at the pinned commit during the build.
