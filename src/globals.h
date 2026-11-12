/**
 * @file globals.h
 * @brief Declarations for globally accessible variables and functions.
 */
#pragma once

// local includes
#include "entry_handler.h"
#include "thread_pool.h"

/**
 * @brief A thread pool for processing tasks.
 */
extern thread_pool_util::ThreadPool task_pool;

/**
 * @brief A boolean flag to indicate whether the cursor should be displayed.
 */
extern bool display_cursor;

#ifdef _WIN32
  // Declare global singleton used for NVIDIA control panel modifications
  #include "platform/windows/nvprefs/nvprefs_interface.h"

/**
 * @brief A global singleton used for NVIDIA control panel modifications.
 */
extern nvprefs::nvprefs_interface nvprefs_instance;
#endif

/**
 * @brief Handles process-wide communication.
 */
namespace mail {
#define MAIL(x) \
  constexpr auto x = std::string_view { \
    #x \
  }

  /**
   * @brief A process-wide communication mechanism.
   */
  extern safe::mail_t man;

  // Global mail
  MAIL(shutdown);
  MAIL(broadcast_shutdown);
  MAIL(video_packets);
  MAIL(audio_packets);
  MAIL(switch_display);

  // Local mail
  MAIL(touch_port);
  MAIL(idr);
  MAIL(invalidate_ref_frames);
  MAIL(gamepad_feedback);
  MAIL(hdr);
  MAIL(dynamic_bitrate);  // Runtime encoder bitrate change (kbps), posted from the HTTP /bitrate handler
#undef MAIL

  /**
   * @brief Select the queue that receives a session's encoded packets.
   *
   * A session that registers its own queue under @p id in its mailbox consumes its packets
   * itself, as the Tizen WebRTC stream does. Every other session publishes to the process-wide
   * queue drained by the GameStream broadcast threads.
   */
  template<class T>
  safe::mail_raw_t::queue_t<T> packet_queue(const safe::mail_t &session_mail, std::string_view id) {
    if (session_mail && session_mail->has(id)) {
      return session_mail->queue<T>(id);
    }
    return man->queue<T>(id);
  }

}  // namespace mail
