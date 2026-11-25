/**
 * @file tests/unit/test_stream_protocol_selection.cpp
 * @brief Tests for choosing which streaming protocols the host serves.
 */
#include "../tests_common.h"

#include <src/config.h>

using config::stream_protocol_e;

TEST(StreamProtocolSelection, ReadsTheThreeValues) {
  EXPECT_EQ(config::parse_stream_protocol("moonlight"), stream_protocol_e::moonlight);
  EXPECT_EQ(config::parse_stream_protocol("webrtc"), stream_protocol_e::webrtc);
  EXPECT_EQ(config::parse_stream_protocol("both"), stream_protocol_e::both);
  EXPECT_EQ(config::parse_stream_protocol("Both"), std::nullopt);
  EXPECT_EQ(config::parse_stream_protocol(""), std::nullopt);
}

TEST(StreamProtocolSelection, ServesEachProtocolOnlyWhenAskedFor) {
  EXPECT_TRUE(config::serves_moonlight(stream_protocol_e::moonlight, true));
  EXPECT_FALSE(config::serves_tvs(stream_protocol_e::moonlight, true));

  EXPECT_FALSE(config::serves_moonlight(stream_protocol_e::webrtc, true));
  EXPECT_TRUE(config::serves_tvs(stream_protocol_e::webrtc, true));

  EXPECT_TRUE(config::serves_moonlight(stream_protocol_e::both, true));
  EXPECT_TRUE(config::serves_tvs(stream_protocol_e::both, true));
}

TEST(StreamProtocolSelection, ABuildWithoutTheTvServerServesMoonlight) {
  // Asking for TVs alone must not leave a build without the TV server serving nothing.
  for (const auto protocol : {stream_protocol_e::moonlight, stream_protocol_e::webrtc, stream_protocol_e::both}) {
    EXPECT_TRUE(config::serves_moonlight(protocol, false));
    EXPECT_FALSE(config::serves_tvs(protocol, false));
  }
}
