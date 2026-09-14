#!/usr/bin/env bash
set -Eeuo pipefail

SSM_REPO="https://github.com/Mydayyy/Valheim-ServerSideMap.git"
SSM_COMMIT="05876ad69e3de25c225740c24f5f0dde155128c5"
SSM_VERSION="1.3.14"
SSM_PACKAGE_VERSION="1.3.14"
SSM_PACKAGE_REVISION="0"
BEPINEX_VERSION="5.4.2350"

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
WORK="${RUNNER_TEMP:-/tmp}/serversidemap-build"
SRC="$WORK/Valheim-ServerSideMap"
VALHEIM="$WORK/valheim-server"
STEAMCMD="$WORK/steamcmd"
BEP="$WORK/bepinex"
OUT_DIR="$ROOT/dist/build"
OUT="$OUT_DIR/ServerSideMap.dll"
LICENSE_OUT="$OUT_DIR/LICENSE-MIT"

rm -rf "$WORK"
mkdir -p "$WORK" "$STEAMCMD" "$BEP" "$OUT_DIR"

sudo apt-get update -qq
sudo DEBIAN_FRONTEND=noninteractive apt-get install -y -qq \
  lib32gcc-s1 lib32stdc++6 curl unzip ca-certificates

curl -fsSL --retry 5 \
  https://steamcdn-a.akamaihd.net/client/installer/steamcmd_linux.tar.gz \
  | tar -xz -C "$STEAMCMD"

steam_ok=0
for attempt in 1 2 3 4 5; do
  echo "SteamCMD Valheim install attempt $attempt/5"
  if "$STEAMCMD/steamcmd.sh" \
      +@sSteamCmdForcePlatformType linux \
      +force_install_dir "$VALHEIM" \
      +login anonymous \
      +app_update 896660 -beta public validate \
      +quit; then
    steam_ok=1
    break
  fi
  echo "SteamCMD attempt $attempt failed; retrying after 5s..." >&2
  sleep 5
done

if [[ "$steam_ok" != 1 ]]; then
  echo "ERROR: could not download Valheim dedicated server after 5 attempts" >&2
  exit 1
fi

curl -fL --retry 5 \
  "https://thunderstore.io/package/download/denikson/BepInExPack_Valheim/${BEPINEX_VERSION}/" \
  -o "$WORK/bepinex.zip"
unzip -q "$WORK/bepinex.zip" -d "$BEP"

git clone --quiet "$SSM_REPO" "$SRC"
git -C "$SRC" checkout --quiet "$SSM_COMMIT"

MANAGED="$VALHEIM/valheim_server_Data/Managed"
LIBS="$SRC/Libs"
mkdir -p "$LIBS" "$SRC/ServerSideMap/bin/Release"

if [[ ! -d "$MANAGED" ]]; then
  echo "ERROR: Valheim Managed directory not found: $MANAGED" >&2
  exit 1
fi

copy_named() {
  local name="$1"
  local root="$2"
  local found
  found="$(find "$root" -type f -name "$name" -print -quit 2>/dev/null || true)"
  if [[ -z "$found" ]]; then
    echo "ERROR: required assembly not found: $name under $root" >&2
    exit 1
  fi
  cp -f "$found" "$LIBS/$name"
}

for name in 0Harmony.dll BepInEx.dll BepInEx.Harmony.dll; do
  copy_named "$name" "$BEP"
done

for name in \
  assembly_utils.dll \
  assembly_valheim.dll \
  Splatform.dll \
  Unity.TextMeshPro.dll \
  UnityEngine.dll \
  UnityEngine.CoreModule.dll \
  UnityEngine.ImageConversionModule.dll \
  UnityEngine.InputLegacyModule.dll \
  UnityEngine.UI.dll
do
  if [[ ! -s "$MANAGED/$name" ]]; then
    echo "ERROR: required Valheim assembly missing: $MANAGED/$name" >&2
    exit 1
  fi
done

DOTNET_ROOT_REAL="$(dirname "$(readlink -f "$(command -v dotnet)")")"
SDK_VERSION="$(dotnet --version)"
CSC="$DOTNET_ROOT_REAL/sdk/$SDK_VERSION/Roslyn/bincore/csc.dll"

if [[ ! -f "$CSC" ]]; then
  CSC="$(find "$DOTNET_ROOT_REAL/sdk" -path '*/Roslyn/bincore/csc.dll' -type f | sort -V | tail -1)"
fi
if [[ -z "${CSC:-}" || ! -f "$CSC" ]]; then
  echo "ERROR: Roslyn csc.dll not found under $DOTNET_ROOT_REAL/sdk" >&2
  dotnet --info >&2 || true
  exit 1
fi

refs=()
while IFS= read -r -d '' dll; do
  refs+=("-r:$dll")
done < <(find "$MANAGED" -maxdepth 1 -type f -name '*.dll' -print0 | sort -z)

for dll in "$LIBS/0Harmony.dll" "$LIBS/BepInEx.dll" "$LIBS/BepInEx.Harmony.dll"; do
  refs+=("-r:$dll")
done

sources=()
while IFS= read -r -d '' source; do
  sources+=("$source")
done < <(
  find "$SRC/ServerSideMap" -type f -name '*.cs' \
    ! -path '*/obj/*' \
    ! -path '*/bin/*' \
    -print0 | sort -z
)

if [[ ${#sources[@]} -eq 0 ]]; then
  echo "ERROR: no ServerSideMap C# sources found at commit $SSM_COMMIT" >&2
  exit 1
fi

BUILT="$SRC/ServerSideMap/bin/Release/ServerSideMap.dll"

echo "Compiling ServerSideMap upstream $SSM_VERSION ($SSM_COMMIT) with Roslyn $SDK_VERSION"
echo "Hexium package version: $SSM_PACKAGE_VERSION (revision $SSM_PACKAGE_REVISION)"
echo "Valheim/BepInEx references: ${#refs[@]}"
echo "Upstream C# sources: ${#sources[@]}"

dotnet "$CSC" \
  -nologo \
  -noconfig \
  -nostdlib+ \
  -target:library \
  -langversion:8.0 \
  -optimize+ \
  -deterministic+ \
  -out:"$BUILT" \
  "${refs[@]}" \
  "${sources[@]}"

if [[ ! -s "$BUILT" ]]; then
  echo "ERROR: ServerSideMap build did not produce $BUILT" >&2
  exit 1
fi

cp -f "$BUILT" "$OUT"
cp -f "$SRC/LICENSE-MIT" "$LICENSE_OUT"

printf 'Built ServerSideMap upstream %s from %s as Hexium %s\n' \
  "$SSM_VERSION" "$SSM_COMMIT" "$SSM_PACKAGE_VERSION"
sha256sum "$OUT"
