#!/usr/bin/env bash
# Drop the local Tizen WebRTC build over the installed Vibeshine package,
# whatever its version. Requires: build-pkg already built, sudo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT}/build-pkg/vibeshine"
WEB_SRC="${ROOT}/build-pkg/assets/web"

die() { echo "error: $*" >&2; exit 1; }

[[ -x "$BIN" ]] || die "missing binary: $BIN (build first)"
[[ -d "$WEB_SRC" ]] || die "missing web assets: $WEB_SRC"
[[ "$(id -u)" -eq 0 ]] || exec sudo -- "$0" "$@"

PKG_VER="$(pacman -Q vibeshine | awk '{print $2}')"
HOST_DST=/usr/libexec/vibeshine/vibeshine-host
CLI_DST=/usr/bin/vibeshine-tizen
CLI_LINK=/usr/bin/vibeshine
CLI_PKG="$(readlink "$CLI_LINK" || true)"
WEB_DST=/usr/share/vibeshine/web

HOST_BAK="${HOST_DST}.${PKG_VER}.bak"
WEB_BAK="${WEB_DST}.${PKG_VER}.bak"

echo "==> installed package: vibeshine ${PKG_VER}"
echo "==> local build: $("$BIN" --version 2>&1 | head -1)"

echo "==> stop vibeshine.service"
systemctl stop vibeshine.service

echo "==> backup package files (once per package version)"
[[ -e "$HOST_BAK" ]] || cp -a "$HOST_DST" "$HOST_BAK"
[[ -e "$WEB_BAK" ]] || cp -a "$WEB_DST" "$WEB_BAK"

echo "==> install host + caps"
install -o root -g vibeshine -m 750 "$BIN" "$HOST_DST"
setcap 'cap_sys_admin,cap_sys_nice=p' "$HOST_DST"

echo "==> install CLI symlink"
install -o root -g root -m 755 "$BIN" "$CLI_DST"
ln -sfn vibeshine-tizen "$CLI_LINK"

echo "==> sync web UI"
rsync -a --delete "${WEB_SRC}/" "${WEB_DST}/"

if command -v ufw >/dev/null && ufw status | grep -q 'Status: active'; then
  echo "==> ufw: allow Tizen WebRTC signaling + discovery from the LAN"
  ufw allow from 192.168.0.0/16 to any port 8000 proto tcp comment 'Vibeshine Tizen WebRTC signaling'
  ufw allow from 192.168.0.0/16 to any port 8000 proto udp comment 'Vibeshine Tizen WebRTC discovery'
fi

echo "==> pacman: keep upgrades from overwriting this build"
if ! grep -Eq '^\s*IgnorePkg\s*=.*\bvibeshine\b' /etc/pacman.conf; then
  if grep -Eq '^\s*IgnorePkg\s*=' /etc/pacman.conf; then
    sed -i -E '0,/^\s*IgnorePkg\s*=/{s/^(\s*IgnorePkg\s*=.*)$/\1 vibeshine/}' /etc/pacman.conf
  else
    sed -i -E '0,/^\[options\]/{s/^\[options\]$/[options]\nIgnorePkg = vibeshine/}' /etc/pacman.conf
  fi
fi
grep -E '^\s*IgnorePkg' /etc/pacman.conf

echo "==> verify"
[[ "$(stat -c '%U:%G:%a' "$HOST_DST")" == "root:vibeshine:750" ]] \
  || die "host ownership/mode wrong"
getcap "$HOST_DST" | grep -q 'cap_sys_admin,cap_sys_nice=p' \
  || die "host capabilities wrong"

echo "==> start vibeshine.service"
systemctl start vibeshine.service
sleep 3
systemctl is-active vibeshine.service
journalctl -u vibeshine.service -b --no-pager -n 60 \
  | grep -Ei 'TV server listening|WebRTC|Started|Failed|error' || true

echo
echo "rollback to package ${PKG_VER}:"
echo "  sudo systemctl stop vibeshine.service"
echo "  sudo cp -a $HOST_BAK $HOST_DST"
echo "  sudo setcap 'cap_sys_admin,cap_sys_nice=p' $HOST_DST"
echo "  sudo ln -sfn ${CLI_PKG:-vibeshine-${PKG_VER%%-*}} $CLI_LINK"
echo "  sudo rsync -a --delete ${WEB_BAK}/ ${WEB_DST}/"
echo "  sudo systemctl start vibeshine.service"
