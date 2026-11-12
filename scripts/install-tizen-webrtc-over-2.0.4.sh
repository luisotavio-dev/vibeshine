#!/usr/bin/env bash
# Drop the local Tizen WebRTC build over the installed Vibeshine 2.0.4 package.
# Requires: build-pkg already built, sudo.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT}/build-pkg/vibeshine"
WEB_SRC="${ROOT}/build-pkg/assets/web"

HOST_DST=/usr/libexec/vibeshine/vibeshine-host
CLI_DST=/usr/bin/vibeshine-tizen
CLI_LINK=/usr/bin/vibeshine
WEB_DST=/usr/share/vibeshine/web

HOST_BAK=/usr/libexec/vibeshine/vibeshine-host.2.0.4.bak
CLI_BAK=/usr/bin/vibeshine-2.0.4.bak
WEB_BAK=/usr/share/vibeshine/web.2.0.4.bak

die() { echo "error: $*" >&2; exit 1; }

[[ -x "$BIN" ]] || die "missing binary: $BIN (build first)"
[[ -d "$WEB_SRC" ]] || die "missing web assets: $WEB_SRC"
[[ "$(id -u)" -eq 0 ]] || exec sudo -- "$0" "$@"

echo "==> stop vibeshine.service"
systemctl stop vibeshine.service

echo "==> backup (once)"
[[ -e "$HOST_BAK" ]] || cp -a "$HOST_DST" "$HOST_BAK"
[[ -e "$CLI_BAK" ]] || cp -a /usr/bin/vibeshine-2.0.4 "$CLI_BAK"
[[ -e "$WEB_BAK" ]] || cp -a "$WEB_DST" "$WEB_BAK"

echo "==> install host + caps"
install -o root -g vibeshine -m 750 "$BIN" "$HOST_DST"
setcap 'cap_sys_admin,cap_sys_nice=p' "$HOST_DST"

echo "==> install CLI symlink"
install -o root -g root -m 755 "$BIN" "$CLI_DST"
ln -sfn vibeshine-tizen "$CLI_LINK"

echo "==> sync web UI"
rsync -a --delete "${WEB_SRC}/" "${WEB_DST}/"

if systemctl is-active --quiet firewalld; then
  echo "==> firewalld: allow TCP 8000"
  firewall-cmd --permanent --add-port=8000/tcp || true
  firewall-cmd --reload || true
else
  echo "==> firewalld inactive — open TCP 8000 yourself if needed"
fi

echo "==> verify"
stat -c 'host %U:%G:%a' "$HOST_DST"
getcap "$HOST_DST"
echo "cli -> $(readlink -f "$CLI_LINK")"
# package expects: root:vibeshine:750 + cap_sys_admin,cap_sys_nice=p
[[ "$(stat -c '%U:%G:%a' "$HOST_DST")" == "root:vibeshine:750" ]] \
  || die "host ownership/mode wrong"
getcap "$HOST_DST" | grep -q 'cap_sys_admin,cap_sys_nice=p' \
  || die "host capabilities wrong"

echo "==> start vibeshine.service"
systemctl start vibeshine.service
sleep 2
systemctl is-active vibeshine.service
journalctl -u vibeshine.service -b --no-pager -n 40 \
  | grep -Ei 'TV server listening|WebRTC|Started|Failed|error' || true

echo
echo "done. backups:"
echo "  $HOST_BAK"
echo "  $CLI_BAK"
echo "  $WEB_BAK"
echo "rollback:"
echo "  sudo systemctl stop vibeshine.service"
echo "  sudo cp -a $HOST_BAK $HOST_DST"
echo "  sudo setcap 'cap_sys_admin,cap_sys_nice=p' $HOST_DST"
echo "  sudo ln -sfn vibeshine-2.0.4 $CLI_LINK"
echo "  sudo rsync -a --delete ${WEB_BAK}/ ${WEB_DST}/"
echo "  sudo systemctl start vibeshine.service"
