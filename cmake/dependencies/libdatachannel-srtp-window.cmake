# Widens libdatachannel's outbound SRTP replay window. Run as a FetchContent patch step:
#   cmake -DSOURCE_DIR=<libdatachannel source> -P libdatachannel-srtp-window.cmake
#
# v0.24.6 protects outgoing SRTP with a 1024-packet window, so libSRTP rejects (srtp_err_status_replay_old)
# any NACK retransmission of a packet more than 1024 packets old. At 4K 50 Mbps that is about 230 ms, while
# the TV video stream keeps NACK_HISTORY_PACKETS (8192) for retransmission. The window must cover that
# history; libSRTP accepts up to 0x8000 packets. The script is idempotent.
set(_file "${SOURCE_DIR}/src/impl/dtlssrtptransport.cpp")
file(READ "${_file}" _content)
set(_old "outbound.window_size = 1024;")
set(_new "outbound.window_size = 16384; // Sunshine: cover the TV stream's NACK history")
string(FIND "${_content}" "${_new}" _patched)
if(NOT _patched EQUAL -1)
    return()
endif()
string(FIND "${_content}" "${_old}" _found)
if(_found EQUAL -1)
    message(FATAL_ERROR "libdatachannel outbound SRTP window not found in ${_file}; update the patch")
endif()
string(REPLACE "${_old}" "${_new}" _content "${_content}")
file(WRITE "${_file}" "${_content}")
message(STATUS "libdatachannel: outbound SRTP replay window widened to 16384 packets")
