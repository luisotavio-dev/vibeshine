/**
 * @file tests/unit/test_session_packet_queue.cpp
 * @brief Tests for routing encoded packets to a session's own queue.
 */
#include "../tests_common.h"

#include <src/globals.h>

safe::mail_t mail::man;

TEST(SessionPacketQueue, UsesTheProcessQueueByDefault) {
  mail::man = std::make_shared<safe::mail_raw_t>();
  auto session_mail = std::make_shared<safe::mail_raw_t>();

  const auto queue = mail::packet_queue<int>(session_mail, "test_packets");
  EXPECT_EQ(queue, mail::man->queue<int>("test_packets"));
  EXPECT_EQ(mail::packet_queue<int>(nullptr, "test_packets"), queue);
  mail::man = {};
}

TEST(SessionPacketQueue, UsesTheSessionQueueWhileItIsRegistered) {
  mail::man = std::make_shared<safe::mail_raw_t>();
  auto session_mail = std::make_shared<safe::mail_raw_t>();
  {
    const auto own = session_mail->queue<int>("test_packets");
    EXPECT_TRUE(session_mail->has("test_packets"));
    EXPECT_EQ(mail::packet_queue<int>(session_mail, "test_packets"), own);
    EXPECT_NE(mail::packet_queue<int>(session_mail, "test_packets"), mail::man->queue<int>("test_packets"));
  }

  // The mailbox holds its queues weakly: once the session drops its queue, packets go back to
  // the process queue.
  EXPECT_FALSE(session_mail->has("test_packets"));
  EXPECT_EQ(mail::packet_queue<int>(session_mail, "test_packets"), mail::man->queue<int>("test_packets"));
  mail::man = {};
}
