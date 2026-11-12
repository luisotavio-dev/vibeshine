#!/usr/bin/env bash
# Replace only vibeshine-host (+ CLI) from build-pkg after a local fix rebuild.
set -euo pipefail
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
BIN="${ROOT}/build-pkg/vibeshine"
[[ -x "$BIN" ]] || { echo "missing $BIN"; exit 1; }
[[ "$(id -u)" -eq 0 ]] || exec sudo -- "$0" "$@"

systemctl stop vibeshine.service
install -o root -g vibeshine -m 750 "$BIN" /usr/libexec/vibeshine/vibeshine-host
setcap 'cap_sys_admin,cap_sys_nice=p' /usr/libexec/vibeshine/vibeshine-host
install -o root -g root -m 755 "$BIN" /usr/bin/vibeshine-tizen
ln -sfn vibeshine-tizen /usr/bin/vibeshine
systemctl start vibeshine.service
stat -c 'host %U:%G:%a' /usr/libexec/vibeshine/vibeshine-host
getcap /usr/libexec/vibeshine/vibeshine-host
systemctl is-active vibeshine.service
echo "done — retest long stream; on transient reenum expect: keeping previous monitor map"
