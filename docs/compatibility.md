# What works

Version 1.2 · Effective November 10, 2026

## Devices and pairing

iPhone and iPad with iOS/iPadOS 17 or later. Local IPv4 Wi-Fi and modern sender browsers. Local-command and whole-screen receivers stay open in the foreground. Compatible native streams can use audio background mode or native Picture in Picture; this does not keep the receivers alive. Bonjour announces Still’s own service; it does not create a YouTube Cast target.

## Video sources

YouTube watch, youtu.be, Shorts and live-video links that allow embedding. Direct HTTPS MP4, MOV, M4V, MP3, M4A and HLS (.m3u8) URLs with iOS-compatible codecs. Query-string access tokens are supported. Playlist pages, arbitrary web pages, custom authenticated headers and local HTTP media are not supported.

## Playback and session tools

Play/pause, seeking where supported, player volume, native stream full screen, queue of up to 20 items, queue editing, auto-next, repeat current video, supported playback speeds, skip intervals, HLS quality ceilings, session sleep timer and queue-only remotes. YouTube quality is managed by YouTube. Live media may lack a seekable timeline. Native Picture in Picture is available through supported stream-player controls, and background stream audio is optional. Still provides no background receiver service.

## Privacy and personalization

Five adaptive color themes, system/light/dark appearance, compact spacing, optional supported-device haptics, screen-awake setting, YouTube playback switch, zero developer telemetry, offline legal search, safe user-shared support summary and local wipe.

## Unavailable protocols

No certified Google Cast receiver, YouTube Cast-menu discovery, AirPlay receiving, Miracast, iPhone/iPad whole-screen sending, DRM bypass, YouTube downloading, public exposure of the local HTTP command server or IPv6-only local-link pairing. Optional WebRTC screen-sharing invitations can work over the internet with deployed HTTPS and TURN services. No promise that all provider videos support embedding, speed, seeking or quality changes.

## Whole-screen video

Android 10+ with the Still Sender companion and system capture consent; compatible desktop browsers using HTTPS getDisplayMedia. WebRTC video-only reception, adaptive quality profiles, bounded reconnect attempts and opt-in local video recording. Internet sharing needs a deployed connection service, valid HTTPS and usually TURN. Android and desktop capture may continue while other apps are used, under OS rules. Receiving on iPhone/iPad remains foreground only. No remote input/control of the source device, microphone, system audio, iPhone/iPad sending or guaranteed playback of protected content.
