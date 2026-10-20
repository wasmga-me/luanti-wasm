#!/bin/bash
# Builds Luanti (https://www.luanti.org/, LGPL-2.1-or-later) for the site from
# paradust7's web port: the minetest-wasm build scripts and the Luanti fork
# they pin (5.18.0-dev), with these changes:
# - luanti.diff (Luanti): single player only, so the main menu has no Join
#   Game or Content tabs, no ContentDB buttons, no Host Server option, no
#   update check and no new-version or reinstall prompts, and the pause menu
#   has no Exit to OS; Esc on the main menu does nothing; the page owns full
#   screen, so the game's own is off and its full screen key (F11) asks the
#   page instead, and the window settings the page owns are hidden like on
#   Android; the play page gets the player's files (minetest.conf and the
#   worlds) from wg_request_files(), read on a thread of their own between
#   server steps, as the page must not touch the file system while the game
#   runs;
# - webport.diff (build scripts): static zstd and libzip, no curl or TLS
#   (single player needs no network), no unit tests, and the module takes its
#   canvas, file locations and output from the play page, which writes the
#   game's files into WasmFS before it runs main().
# The build runs on threads with JSPI, like paradust7's.
#
# The play page loads two zips from R2: the engine's files (builtin scripts,
# client shaders, fonts, translations, textures) and Minetest Game.
#
# Needs git, cmake, make, wget, zip, python3, gettext, tcl, Node.js 24 (for
# emsdk, which install_emsdk.sh fetches and patches).
# Usage: bash build.sh [work dir]
# Writes luanti.js and luanti.wasm next to this script, and the zips for R2 to
# <work dir>/r2/luanti/ (upload them to wasmgame-files under the same keys).
# A change to the build here takes the next -p number for this folder.
set -euo pipefail

WEBPORT_REV=5bfae52b53605b39667dfc29cddd59c861e38111 # paradust7/minetest-wasm
MTG_REV=c42e4d0c0ff9d27ff7b9b308c3cfc14098dd3a0f     # luanti-org/minetest_game

here=$(cd "$(dirname "$0")" && pwd)
work=$(mkdir -p "${1:-luanti-build}" && cd "${1:-luanti-build}" && pwd)
cd "$work"

if [ ! -d minetest-wasm ]; then
  git clone -q https://github.com/paradust7/minetest-wasm.git
  git -C minetest-wasm -c advice.detachedHead=false checkout -q "$WEBPORT_REV"
  git -C minetest-wasm apply "$here/webport.diff"
fi
cd minetest-wasm
# fetch_sources.sh pins Luanti (paradust7/luanti 6f532b5) and webshims
./fetch_sources.sh
git -C sources/luanti diff --quiet && git -C sources/luanti apply "$here/luanti.diff"

# fetch_sources.sh (through common.sh) installed and patched emsdk 6.0.8
set +u
source emsdk/emsdk_env.sh >/dev/null
set -u
source "$here/ports.sh"

./build_zstd.sh
./build_libarchive.sh
./build_webshims.sh
./build_libzip.sh
./build_luanti.sh
cp build/luanti/bin/luanti.js build/luanti/bin/luanti.wasm "$here/"

# The zips, with fixed timestamps so the same files give the same zip
cd "$work"
if [ ! -d minetest_game ]; then
  git clone -q https://github.com/luanti-org/minetest_game.git
  git -C minetest_game -c advice.detachedHead=false checkout -q "$MTG_REV"
fi
inst=$work/minetest-wasm/build/luanti-install
stage=$work/stage
rm -rf "$stage"
mkdir -p "$stage/base/bin" "$stage/base/cache" "$stage/games" r2/luanti
cp -r "$inst"/builtin "$inst"/client "$inst"/fonts "$inst"/locale "$inst"/textures "$stage/base/"
echo "This is here to ensure bin exists" > "$stage/base/bin/readme.txt"
# No update check, and no prompts about Minetest Game or key codes on a first visit
printf 'update_last_checked = disabled\nno_mtg_notification = true\nno_keycode_migration_warning = true\n' > "$stage/base/cache/common.conf"
git -C minetest_game archive --format=tar --prefix=minetest_game/ HEAD | tar -x -C "$stage/games"
rm -rf "$stage/games/minetest_game/.github" "$stage/games/minetest_game/utils" "$stage/games/minetest_game"/.[a-z]*
find "$stage" -exec touch -d 2000-01-01T00:00:00Z {} +
z() { (cd "$1" && find . -type f | LC_ALL=C sort | sed 's|^\./||' | TZ=UTC zip -q -X -9 -@ "$2"); }
z "$stage/base" "$stage/base.zip"
z "$stage/games" "$stage/games.zip"
b=$(sha256sum "$stage/base.zip" | cut -c1-12)
g=$(sha256sum "$stage/games.zip" | cut -c1-12)
mv "$stage/base.zip" "r2/luanti/luanti-$b.zip"
mv "$stage/games.zip" "r2/luanti/minetest-game-$g.zip"
rm -rf "$stage"
ls -l r2/luanti
