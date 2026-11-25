# Moonlight WebRTC for Samsung Tizen

Vibeshine can stream to the [Moonlight WebRTC](https://github.com/tsoas/moonlight-webrtc-tizen) app on
Samsung Tizen TVs directly. The TV talks to Vibeshine itself, so the separate Moonlight WebRTC Gateway is
not needed. This is native WebRTC desktop streaming on Linux hosts. It is separate from the browser
stream, which uses libwebrtc and builds only on Windows.

## Why WebRTC

On Tizen 9, Samsung limits Game Mode to devices connected over HDMI. An app on the TV that receives a
network stream does not get it, so the TV keeps its normal picture processing and the stream has visible
delay. The TV's WebRTC stack still reaches Game Mode: an `imageattr` attribute from Samsung's Cloud Gaming
setup, in the video section of the SDP, puts the Tizen decoder in Game Mode.

## Why it is built into Vibeshine

With the Gateway, every frame crossed two transports on the PC before reaching the TV:

```text
encoder ─► GameStream RTP + FEC + AES ─► loopback UDP ─► moonlight-common-c
        (reassembly, FEC, decryption, frame queue) ─► WebRTC packetizer ─► TV
```

Built into Vibeshine, the encoded frame goes from the encoder straight to the WebRTC packetizer:

```text
encoder ─► WebRTC packetizer (RTP over DTLS-SRTP) ─► TV
```

This removes the GameStream packetization, Reed-Solomon FEC, encryption and decryption, the loopback
hop, the client-side frame reassembly and its queue, and a second process. Keyframe requests (RTCP PLI)
reach the encoder directly instead of travelling back through the GameStream control channel. The TV app,
its protocol and the encoded bitstream are the same, so the gain is the host-side pipeline only. The TV's
decode time and the network are unaffected.

Because there is no GameStream FEC to pay for, the video encoder receives the bitrate the TV selected,
less the Opus audio and a small RTP allowance.

## Build

The TV server is built when `SUNSHINE_ENABLE_TIZEN_WEBRTC` is on. It is on by default on Linux and off on
other platforms, where it has not been tested. A build without it serves Moonlight clients only, whatever
`stream_protocol` says.

[libdatachannel](https://github.com/paullouisageneau/libdatachannel) provides WebRTC. When no system
package is found, it is built from source with Vibeshine and linked statically
(`cmake/dependencies/libdatachannel.cmake`). The Linux host links libgcc statically, and an exception
thrown across a shared libdatachannel would abort the host. The fetched source is patched to widen
libSRTP's outbound replay window to 16384 packets, so retransmissions of older packets at 4K bitrates
are not rejected (`cmake/dependencies/libdatachannel-srtp-window.cmake`).

## Setup

1. Set `stream_protocol` to `both` (or `webrtc` for TVs only) in the **Network** tab of the
   configuration page, and restart Vibeshine.
2. If the Moonlight WebRTC Gateway is installed on the same PC, uninstall it or stop its service: both
   use port 8000.
3. On the TV, open Moonlight WebRTC. It finds this PC by broadcasting to UDP port 8000, which Vibeshine
   answers with its name, its `webrtc_port` and its Wake-on-LAN address. On a network that blocks
   broadcasts, add the PC by its address and port.
4. The TV shows a four-digit PIN. In the Web UI, open the PIN page, select the TV in the list of devices
   waiting to pair (it appears beside any Moonlight client), and enter the PIN. The name typed there is
   the TV's name in Vibeshine.

Pairing works like Moonlight's: the TV picks the PIN and only a user signed in to the Web UI can approve
it. The PIN pairs only the pending TV that shows it. Other requests stay pending, and a PIN that no TV
shows goes to a pending Moonlight client. Two pending TVs that show the same PIN are both declined,
because the signaling WebSocket has no TLS and one of them may replay a PIN read off the network. An
unused PIN is replaced after five minutes. Older TV apps, which entered a PIN shown on the PC, are told
to update.

## Configuration

| Option                  | Default     | Description                                                             |
|-------------------------|-------------|-------------------------------------------------------------------------|
| `stream_protocol`       | `moonlight` | `moonlight`, `webrtc` or `both`: which clients Vibeshine serves.        |
| `webrtc_port`           | `8000`      | TCP port of the signaling WebSocket.                                    |
| `webrtc_media_port_min` | `0`         | First UDP port for WebRTC video and audio; 0 with the next one for any. |
| `webrtc_media_port_max` | `0`         | Last UDP port for WebRTC video and audio.                               |

With `moonlight`, the default, the TV server does not start and opens no port. With `webrtc`, Vibeshine
neither publishes itself over mDNS nor listens on the GameStream ports, so a PC can serve TVs only.

TV discovery always listens on UDP port 8000, whatever `webrtc_port` is, and answers only peers on the
local network: loopback, private, link-local and unique local addresses. The socket is shared, so
several Vibeshine instances on one PC, each with its own `webrtc_port`, all answer a TV's broadcast.
A firewall that opens ports needs TCP `webrtc_port`, UDP 8000 and the media range. The ufw profile for
the default ports is separate from the Moonlight one, so opening them stays a choice:

```sh
# ufw
sudo ufw allow 'Vibeshine Tizen WebRTC'
# firewalld
sudo firewall-cmd --permanent --add-port=8000/tcp --add-port=8000/udp && sudo firewall-cmd --reload
```

## Behaviour

The protocol is version 2 of the Moonlight WebRTC Gateway protocol, unchanged, so the existing TV app
works as is. Vibeshine implements it as follows:

- **Applications** come from Vibeshine's application list, with their configured cover art.
- **Starting** an application launches it like a Moonlight launch, including display configuration and
  encoder probing; an application that is already running is resumed. Starting a different application
  while one runs is refused, as Moonlight does; the TV offers to switch instead.
- **Stopping the stream** leaves the application running. **Stopping the application** ends every
  stream, Moonlight's included, and terminates the application.
- **Frame rates** of 30, 60, 90 and 120 fps are offered at every resolution. The TV streams at the
  highest one its decoder announces it sustains, or lets the user choose when it announces none.
- **Codecs** are offered from what the encoder probe found: AV1 only when the GPU encodes it, and AV1 HDR
  only with AV1 Main10. HEVC and HEVC HDR requests fail when the encoder lacks them.
- **HDR** requires the host display to be in HDR mode, or the display device settings to enable it. A
  stream that asked for HDR ends with an error instead of silently sending SDR.
- **Controllers** are announced as Moonlight controllers, so controller emulation and rumble work as with
  any Moonlight client. Holding Start toggles mouse emulation.
- **Paired TVs** appear in the client list like Moonlight clients. A TV can be disabled there, which keeps
  it paired but refuses it until it is enabled again, or unpaired. They are stored in
  `webrtc_tv_clients.json` in the configuration directory, readable by its owner only.
- **Latency.** Video packets carry the WebRTC playout-delay extension set to zero, which TVs that accept
  it in their answer honour by showing each frame the moment it is decoded, with no jitter buffer
  smoothing. Audio is sent in a media stream of its own, so the TV does not hold the picture back to
  keep lip sync.

## Web UI API

| Endpoint                       | Description                                         |
|--------------------------------|-----------------------------------------------------|
| `GET /api/pin`                 | Lists TVs waiting to pair beside Moonlight clients. |
| `POST /api/pin`                | Pairs the TV that shows the PIN.                    |
| `DELETE /api/pin`              | Declines the selected TV's pairing request.         |
| `GET /api/clients/list`        | Lists paired TVs beside Moonlight clients.          |
| `POST /api/clients/update`     | Enables or disables a TV; disabling disconnects it. |
| `POST /api/clients/unpair`     | Forgets one TV and disconnects it.                  |
| `POST /api/clients/unpair-all` | Forgets every client, TVs included.                 |

## Implementation

| File                                          | Role                                                                 |
|-----------------------------------------------|----------------------------------------------------------------------|
| `src/tizen_webrtc/webrtc_stream.cpp`          | Signaling server, TV sessions, application lifecycle, media pumping. |
| `src/tizen_webrtc/webrtc_stream_disabled.cpp` | The same API for builds without the TV server.                       |
| `src/tizen_webrtc/protocol.cpp`               | Protocol messages, stream settings and the media port range.         |
| `src/tizen_webrtc/tv_auth.cpp`                | TV pairing requests, credential store and HMAC authentication.       |
| `src/tizen_webrtc/sdp.cpp`                    | Samsung Game Mode `imageattr` and HEVC Main10 SDP handling.          |
| `src/tizen_webrtc/input_bridge.cpp`           | Gamepad snapshots to Moonlight input packets, mouse mode, rumble.    |

The encoders publish to a process-wide queue drained by the GameStream sender. A session can register its
own `video_packets` and `audio_packets` queues in its mailbox (`mail::packet_queue()`); the TV stream
does, so its frames never reach the GameStream sender. Moonlight sessions are unaffected.

The tests are in `tests/unit/tizen_webrtc/`.
