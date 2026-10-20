# Emscripten ports that download GitHub archive links, which some networks block:
# this clones each at the same tag into the emsdk cache and marks it unpacked.
# Usage: port <name> <repo> <tag> <dir in the archive> <url emscripten fetches>
port() {
  cache=$(em-config CACHE)/ports
  dir="$cache/$1"
  if [ "$(cat "$dir/.emscripten_url" 2>/dev/null)" = "$5" ]; then return; fi
  rm -rf "$dir"
  mkdir -p "$dir"
  git -c advice.detachedHead=false clone -q --depth 1 -b "$3" "https://github.com/$2.git" "$dir/$4"
  echo "$5" > "$dir/.emscripten_url"
}
# The versions emsdk 6.0.8 asks for
port zlib madler/zlib v1.3.2 zlib-1.3.2 https://github.com/madler/zlib/archive/refs/tags/v1.3.2.tar.gz
port freetype freetype/freetype VER-2-14-3 freetype-VER-2-14-3 https://github.com/freetype/freetype/archive/VER-2-14-3.zip
port sdl2 libsdl-org/SDL release-2.32.10 SDL-release-2.32.10 https://github.com/libsdl-org/SDL/archive/release-2.32.10.zip
