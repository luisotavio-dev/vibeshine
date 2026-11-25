/**
 * @file src/tizen_webrtc/webrtc_stream_disabled.cpp
 * @brief Moonlight WebRTC TV server API for builds without the server.
 *
 * The HTTP handlers list, pair and unpair TVs next to Moonlight clients. Without the server there
 * are no TVs, so every call reports that no TV took part and the handlers fall back to Moonlight.
 */
// local includes
#include "webrtc_stream.h"

namespace tizen_webrtc {
  void start() {
  }

  int session_count() {
    return 0;
  }

  std::vector<pending_tv_pairing_t> pending_tv_pairings() {
    return {};
  }

  std::optional<bool> approve_tv_pairing(std::string_view, std::string_view, std::string_view) {
    return std::nullopt;
  }

  std::optional<bool> approve_tv_pairing_by_pin(std::string_view, std::string_view) {
    return std::nullopt;
  }

  std::optional<bool> cancel_tv_pairing(std::string_view) {
    return std::nullopt;
  }

  std::vector<paired_tv_t> paired_tvs() {
    return {};
  }

  std::optional<bool> unpair_tv(std::string_view) {
    return std::nullopt;
  }

  std::optional<bool> set_tv_enabled(std::string_view, bool) {
    return std::nullopt;
  }

  std::optional<std::size_t> unpair_all_tvs() {
    return std::nullopt;
  }
}  // namespace tizen_webrtc
