# Whole-screen sharing

Version 1.2 · Effective November 10, 2026

## 1. One-time connection setup

The app distributor or your administrator deploys the included HTTPS connection service and a TURN relay, then configures the service address in Still → Settings → Screen sharing. No hosted service is preconfigured in this source project. If you run your own service, use the repository deployment guide and a domain with a valid TLS certificate. This setup is required before normal users can receive an invitation.

## 2. Invite a screen

On the receiving iPhone/iPad, choose Receive a whole screen, then Create an invitation. Share or scan the invitation on the sending device. Keep the invitation private. It allows one sending device per session. Starting screen mode stops the local link receiver and its current video to keep the two modes clear.

## 3. Share from Android or a computer

On Android, install the Still Sender companion, open the invitation from the browser’s Open Android sender button or paste the full link into the companion. Choose a quality profile and whether recording is allowed, then choose a screen in Android’s permission dialog. On a supported computer browser, open the invitation, choose a profile and press Choose a screen. Your browser shows its own screen picker. iPhone/iPad whole-screen sending is not supported in this release.

## 4. Record only with permission

The sender must allow recording before joining; it is off by default. On the receiver, Record this screen stores video-only MP4 locally, without audio. The sender sees a recording notice. Stop & save finalizes it. Recordings are capped at 30 minutes and stop when storage is low. Find, preview, share or delete recordings in Settings → Recordings. Local Wipe deletes them. External screen capture cannot be prevented by this consent setting.

## 5. Nearby, distant and interrupted connections

The same invitation flow works nearby or across networks when the configured services can establish a WebRTC path. Congested Wi-Fi, mobile networks, firewalls, VPNs and long distances affect quality and delay. Try Lighter connection if needed. Both clients make bounded reconnection attempts after interruptions. Restart the invitation if recovery fails. The supplied service limits sessions to two hours and briefly preserves room state after a receiver disconnect.

## 6. Background and stop controls

The Android sender uses a visible foreground media-projection service, and desktop capture can continue while another app is used where the sender OS allows it. Android lock or OS policies can revoke capture. The iPhone/iPad receiver must remain open for whole-screen receiving and recording. Backgrounding it ends screen sharing and saves any active recording if the OS gives time. Separate direct-stream playback may use native Picture in Picture or optional background audio; neither keeps screen receiving alive.

## 7. Privacy and source restrictions

Screen video only is sent in this release. No camera, microphone, system audio or remote control of the sender. Notifications and private text visible on the selected screen can be exposed. Protected video can appear black, and provider restrictions are not bypassed. Signaling/TURN operators process connection metadata; WebRTC encrypts media in transit. Read the full bundled Privacy Policy and trust the configured service operator.
