#!/bin/sh
set -eu

LUA_VERSION=5.1.5
LUA_URL=https://www.lua.org/ftp/lua-5.1.5.tar.gz
LUA_SHA256=2640fc56a795f29d28ef15e13c34a47e223960b0240e8cb0a82d9b0738695333
LUAROCKS_VERSION=3.13.0
LUAROCKS_URL=https://luarocks.github.io/luarocks/releases/luarocks-3.13.0.tar.gz
LUAROCKS_SHA256=245bf6ec560c042cb8948e3d661189292587c5949104677f1eecddc54dbe7e37

ROOT="${XDG_DATA_HOME:-$HOME/.local/share}/toku"
SRC="$ROOT/src"

say () {
  printf '[setup]\t%s\n' "$1"
}

die () {
  printf '[setup]\terror: %s\n' "$1" >&2
  exit 1
}

need () {
  command -v "$1" >/dev/null 2>&1 || die "missing required tool: $1"
}

sha () {
  if command -v sha256sum >/dev/null 2>&1; then
    sha256sum -- "$1" | awk '{print $1}'
  elif command -v shasum >/dev/null 2>&1; then
    shasum -a 256 -- "$1" | awk '{print $1}'
  elif command -v openssl >/dev/null 2>&1; then
    openssl dgst -sha256 -r "$1" | awk '{print $1}'
  else
    die "missing sha256sum, shasum, or openssl"
  fi
}

get () {
  if command -v curl >/dev/null 2>&1; then
    curl -fSL -o "$1" "$2"
  elif command -v wget >/dev/null 2>&1; then
    wget -q -O "$1" -- "$2"
  else
    die "missing curl or wget"
  fi
}

fetch () {
  dest="$SRC/$1"
  url="$2"
  want="$3"
  if [ -f "$dest" ] && [ "$(sha "$dest")" = "$want" ]; then
    say "cached $1"
    return
  fi
  rm -f "$dest" "$dest.part"
  say "fetching $url"
  get "$dest.part" "$url"
  got="$(sha "$dest.part")"
  [ "$got" = "$want" ] || die "sha256 mismatch for $1 (want $want got $got)"
  mv "$dest.part" "$dest"
  say "ok $dest"
}

for t in cc make tar unzip; do
  need "$t"
done
command -v curl >/dev/null 2>&1 || command -v wget >/dev/null 2>&1 || die "missing curl or wget"

case "$ROOT" in
  *' '*) die "managed root contains whitespace: $ROOT" ;;
esac

mkdir -p "$SRC"

fetch "lua-$LUA_VERSION.tar.gz" "$LUA_URL" "$LUA_SHA256"
fetch "luarocks-$LUAROCKS_VERSION.tar.gz" "$LUAROCKS_URL" "$LUAROCKS_SHA256"

rm -rf "$SRC/lua-$LUA_VERSION" "$SRC/luarocks-$LUAROCKS_VERSION"
tar -xzf "$SRC/lua-$LUA_VERSION.tar.gz" -C "$SRC"
tar -xzf "$SRC/luarocks-$LUAROCKS_VERSION.tar.gz" -C "$SRC"

PLAT="$(uname -s)"
say "building lua $LUA_VERSION ($PLAT)"
case "$PLAT" in
  Darwin)
    (cd "$SRC/lua-$LUA_VERSION" && make macosx)
    ;;
  Linux)
    (cd "$SRC/lua-$LUA_VERSION" && make -C src all CC=cc \
      "MYCFLAGS=-DLUA_USE_POSIX -DLUA_USE_DLOPEN" "MYLIBS=-Wl,-E -ldl")
    ;;
  *)
    (cd "$SRC/lua-$LUA_VERSION" && make -C src all CC=cc \
      "MYCFLAGS=-DLUA_USE_POSIX -DLUA_USE_DLOPEN" "MYLIBS=-Wl,-E")
    ;;
esac
(cd "$SRC/lua-$LUA_VERSION" && make install "INSTALL_TOP=$ROOT/lua")
[ -x "$ROOT/lua/bin/lua" ] || die "lua build did not produce $ROOT/lua/bin/lua"

say "building luarocks $LUAROCKS_VERSION"
(cd "$SRC/luarocks-$LUAROCKS_VERSION" &&
  sh ./configure "--prefix=$ROOT/luarocks" "--with-lua=$ROOT/lua" "--rocks-tree=$ROOT/rocks" &&
  make -f GNUmakefile all &&
  make -f GNUmakefile install)
[ -x "$ROOT/luarocks/bin/luarocks" ] || die "luarocks build did not produce $ROOT/luarocks/bin/luarocks"

CFG="$ROOT/luarocks/etc/luarocks/config-5.1.lua"
grep -q 'name = "toku"' "$CFG" 2>/dev/null ||
  printf 'rocks_trees = {\n  { name = "toku", root = "%s/rocks" },\n}\n' "$ROOT" >> "$CFG"

say "installing santoku-cli"
(cd "$ROOT" &&
  PATH="$ROOT/rocks/bin:$ROOT/luarocks/bin:$ROOT/lua/bin:$PATH" \
  LUAROCKS_CONFIG="$CFG" \
  "$ROOT/luarocks/bin/luarocks" install santoku-cli)
[ -x "$ROOT/rocks/bin/toku" ] || die "santoku-cli install did not produce $ROOT/rocks/bin/toku"

printf 'return {\n  mode = "managed",\n  lua = "%s",\n  luarocks = "%s",\n  cli = "%s",\n  platform = "%s",\n  created = "%s",\n}\n' \
  "$LUA_VERSION" "$LUAROCKS_VERSION" "bootstrap" "$PLAT" "$(date -u +%Y-%m-%dT%H:%M:%SZ)" \
  > "$ROOT/manifest.lua"

say "managed toolchain ready at $ROOT"
say "managed toku: $ROOT/rocks/bin/toku"
say "optional PATH wiring:"
say "  export PATH=\"$ROOT/rocks/bin:$ROOT/luarocks/bin:$ROOT/lua/bin:\$PATH\""
