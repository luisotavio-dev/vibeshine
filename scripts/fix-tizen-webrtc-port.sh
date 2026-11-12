#!/usr/bin/env bash
# Free TCP/UDP 8000 from moonlight-webrtc gateway, keep Vibeshine Tizen server up.
set -euo pipefail

die() { echo "error: $*" >&2; exit 1; }
info() { echo "==> $*"; }

PORT="${WEBRTC_PORT:-8000}"

info "stop + disable user moonlight-webrtc (frees :${PORT})"
systemctl --user stop moonlight-webrtc.service 2>/dev/null || true
systemctl --user disable moonlight-webrtc.service 2>/dev/null || true
# leftover process if unit name differs
pkill -x moonlight-webrtc 2>/dev/null || true
sleep 1

if ss -ltn | awk -v p=":${PORT}" '$4 ~ p"$" {found=1} END {exit !found}'; then
  # still listening — only OK if vibeshine-host owns it after restart
  info "something still listening on :${PORT} before restart"
fi

info "restart vibeshine host"
sudo systemctl restart vibeshine.service
# session stack can cancel a bare restart; wait and ensure active
for i in 1 2 3 4 5 6 7 8 9 10; do
  if systemctl is-active --quiet vibeshine.service; then
    break
  fi
  sleep 1
done
systemctl is-active --quiet vibeshine.service || die "vibeshine.service not active"

info "wait for TV server log"
ok=0
for i in $(seq 1 20); do
  if journalctl -u vibeshine.service -b --no-pager -n 80 \
      | grep -Fq "WebRTC: TV server listening on port ${PORT}"; then
    ok=1
    break
  fi
  if journalctl -u vibeshine.service -b --no-pager -n 40 \
      | grep -Fq "TV server failed to start on port ${PORT}"; then
    die "TV server still failed to bind :${PORT} — check: ss -ltnp | grep :${PORT}"
  fi
  sleep 1
done
[[ "$ok" -eq 1 ]] || die "no 'TV server listening' line yet — see: journalctl -u vibeshine.service -b -n 50"

info "status"
systemctl --user is-active moonlight-webrtc.service 2>/dev/null || echo "moonlight-webrtc: inactive"
systemctl --user is-enabled moonlight-webrtc.service 2>/dev/null || echo "moonlight-webrtc: disabled"
systemctl is-active vibeshine.service
ss -ltn | awk -v p=":${PORT}" '$4 ~ p"$" {print "LISTEN",$4}' || true
journalctl -u vibeshine.service -b --no-pager -n 20 \
  | grep -Ei "TV server listening|failed to start|WebRTC" || true

echo
echo "next:"
echo "  1) Web UI Settings → Network: stream_protocol=both (save/restart if asked)"
echo "  2) TV Moonlight WebRTC → <PC-IP>:${PORT}"
echo "  3) Pair PIN in Vibeshine Pair page"
echo "  4) Stream Desktop / Steam Dummy"
