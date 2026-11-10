# Whole-screen sharing · Still 1.2

Still now includes an optional WebRTC screen receiver for iPhone/iPad, a desktop browser sender and a separate Android sender. These are an additional mode, independent of YouTube’s Cast menu and the local video-link remote.

## User flow

Once an administrator/distributor has configured the connection service, the receiving user opens **Receive a whole screen → Create an invitation**. The other device opens that invitation. A supported computer browser asks which screen/window/tab to share. Android opens the Still Sender companion, which asks for Android’s system capture permission. Choose a quality profile and whether receiver recording is allowed. Recording consent is off by default.

The Android sender can capture while other apps are used through its visible foreground media-projection service. Use its notification or Stop sharing button to stop. The browser has its own capture indicator and stop control. OS lock, resource policies, network changes and capture revocation may stop either sender. iPhone/iPad whole-screen sending is **not implemented**.

The receiver shows the screen and offers full screen and opt-in recording. **Screen video only** is implemented; no microphone, system audio or remote input control. Protected media may be black. No DRM or capture-policy bypass is included.

## Long-distance connections need infrastructure

A public HTTPS signaling endpoint and, for restrictive networks, a TURN relay are required. The project supplies the service source, configuration templates and deployment instructions, but does not supply a running public server, domain, TLS certificate or free relay bandwidth. No production endpoint was deployed in the authoring session.

Deploy `relay/` on your own domain with valid TLS, configure STUN/TURN, and enter the HTTPS origin in **Settings → Screen sharing**. This is one-time distributor/administrator setup; users should not need to type SDP, IP addresses or port numbers. For a consumer release, provision the service before distributing the app and explain the operator’s privacy practices and any hosting costs.

No public STUN/TURN provider is silently selected. ICE uses configured servers; absence of relay infrastructure means some network combinations will fail. A TURN relay transports encrypted WebRTC media but sees endpoint addresses, timing and traffic volume. The signaling service sees credentials and negotiation metadata. This processing is distinct from analytics; zero developer telemetry does not mean no operational metadata.

## Recording

The sender must opt in before joining. The receiver enables Record only after that permission is delivered. It notifies the sender when recording starts/stops. This applies to the supplied apps and cannot prevent external screenshots, cameras or modified clients.

Recording encodes video-only MP4 locally, capped at 24 fps and a 1280-pixel long edge, with a 30-minute per-recording cap and low-storage stop. It drops excess frames instead of accumulating a frame backlog. Rotation is baked into frames; later aspect-ratio changes are fitted within the recording’s initial canvas. Recordings may contain letterboxing. Actual encoding performance still requires device testing.

Saved recordings appear under Settings → Recordings for preview, system sharing and deletion. They are excluded from backup by the app. Local Wipe deletes them, including incomplete files. Exported copies, remote records and OS backups cannot be recalled. Recording errors and partial cleanup must be treated as real failures, not successful erasure.

## Background behavior

| Function | Supported behavior |
| --- | --- |
| Android screen sender | System-approved foreground media-projection service with visible stop notification; can continue while other apps are used |
| Desktop browser sender | Browser capture can continue outside the selected page where browser/OS permits |
| iPhone/iPad whole-screen receiver | Foreground only; backgrounds end the session and stop recording |
| Local HTTP link receiver | Foreground only; backgrounds revoke local pairing |
| Compatible native direct stream | Optional background audio, and native Picture in Picture where supported and started by the user |
| YouTube embed | Pauses when the app backgrounds |
| Finalizing a recording | A bounded iOS background task requests time to finish the file; no indefinite guarantee |

The audio background mode is used for actual native media audio. No silent-audio, private-API or fake-VoIP keepalive is used. iOS does not allow an arbitrary screen receiver/server to run forever in the background. No implementation can guarantee zero latency, permanent connectivity, or uninterrupted capture across outages.

## What was verified

The relay has socket-level protocol tests and a dependency audit. Android Java source was compiled against the Android 36 platform and pinned WebRTC/OkHttp dependencies with Eclipse ECJ; this does not produce or validate an APK. Native Swift syntax was parsed; Apple SDK compilation and device execution remain pending. See `VALIDATION.md` for browser media-test results and remaining checks. Do not market this as tested native screen mirroring until the release checks pass.
