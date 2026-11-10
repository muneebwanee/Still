# Privacy Policy · Zero Telemetry

Version 1.2 · Effective November 10, 2026

## In plain words

Still sends no analytics, usage events, advertising identifiers, automatic crash reports or viewing history to its developer. There is no Still account or preconfigured developer cloud service. Local video-link receiving needs no backend; optional whole-screen sharing uses the connection service you configure. Your settings stay on this device; your queue and pairing session stay in memory. This is what “zero developer telemetry” means in this app.

Playing online video necessarily contacts the chosen media provider. YouTube, Google, a stream host, your operating system and your network may process information under their own policies. This policy does not claim that online playback is anonymous or that no network traffic exists.

## 1. Who is responsible and what this covers

Still is developed by muneebwanee, reachable at https://github.com/muneebwanee. This policy covers the Still iPhone/iPad app, its bundled local browser remote the Android Sender companion, optional connection-service source, and app-controlled data processing. It applies to this version from the effective date above. It does not govern GitHub, Apple, YouTube, browsers, routers or independently operated video sources.

The local-link mode does not send playback activity to an app server. Optional screen sharing necessarily sends negotiation and connection metadata to your selected operator; it is not an analytics upload. If you voluntarily contact the developer or publicly post an issue, the information you choose to provide is processed by the contact platform and may become public. Never include a pairing link or private media URL in a public report.

## 2. Information stored on your device

Still stores small preferences in iOS UserDefaults: onboarding completion, receiver name, appearance and color theme, compact-layout and haptic choices, screen-awake and auto-next preferences, skip interval, stream quality, repeat and speed preferences, queue-only mode whether YouTube playback is allowed, background stream-audio preference, and the optional screen-sharing service address. These preferences are not a watch history and are not automatically sent to the developer.

During use, memory holds the current media URL and title, video ID where relevant, pending queue, playback position and duration, player volume and state, sleep-timer deadline, a local network address, the temporary pairing token and the time of the most recent accepted remote command. Queue and session information are not intentionally written to a persistent history database. User-provided titles and receiver names can themselves contain personal information, so avoid sensitive names when sharing a session.

## 3. Information Still does not collect for telemetry

Still has no analytics SDK, advertising SDK, tracking pixel, fingerprinting service, developer crash-reporting upload, telemetry endpoint or account identifier. It does not sell personal information, build advertising profiles, run advertisements of its own, or combine activity across applications for advertising. There is no developer-side viewing database to export or delete.

This promise concerns app-authored collection. Apple may receive diagnostics according to your device and App Store settings. Your browser or operating system may maintain independent logs, network records, backups or security reports. Still cannot change those settings or represent that such system records do not exist.

## 4. Local pairing and people on your network

Starting the receiver advertises Still’s own Bonjour service on Wi-Fi and opens a local HTTP listener. The displayed QR code contains a device address and a temporary random token. The token grants access to the local remote API until receiving stops. It changes on restart, on disconnecting all remotes, and after local wipe. No pairing information is sent to a developer server.

A paired remote can see the current title, source, playback status, timeline, player volume, queue titles and playback error. In full-control mode it can replace, queue, pause, resume, seek, stop or skip videos and change player volume. In queue-only mode it can read session status and add videos, while the receiver rejects transport and replacement commands. Queue-only is not a confidentiality boundary: paired users can still see titles and status.

Local remote traffic uses HTTP and is not encrypted. The token is an access credential, not encryption. A person intercepting your network traffic or obtaining the complete pairing link may control the receiver. Use trusted private Wi-Fi. Do not forward its listening port to the internet. Disconnect all remotes or stop the receiver when access should end.

## 5. Online media and YouTube

Direct-stream playback connects the receiving device to the URL you choose and possibly to hosts referenced by its media playlist. Such hosts may receive your IP address, request headers, media URL, access tokens included in the URL, timestamps, device or playback information and other network metadata. The browser remote sends the link to Still; Still does not proxy the video through its developer.

YouTube playback uses the official iframe API and privacy-enhanced embed host in a nonpersistent WKWebView data store. Loading the player and playing a video contacts YouTube/Google services, including their API and media hosts. They may receive your IP address, video identifier, device/browser information, playback events and other information under Google’s Privacy Policy at https://policies.google.com/privacy and YouTube’s terms at https://www.youtube.com/t/terms. Privacy-enhanced mode does not eliminate provider processing. Provider ads or cookies may be involved according to provider behavior and applicable rules.

You can disable YouTube playback in Privacy & Data. This stops a current YouTube video and removes queued YouTube entries; new YouTube loads are rejected while disabled. This control does not block network requests made by direct media sources, nor does it erase records already held by providers.

## 6. Permissions and device features

Still requests Local Network permission when you start receiving, for Bonjour advertisement and local commands. iOS decides whether and when to display the permission request. Denial can be changed in iOS Settings. The receiving iOS app does not request camera, microphone, photos, location, contacts, notifications or App Tracking Transparency authorization.

The receiving device displays a QR code; your other device scans it using its own camera or browser. Sharing a pairing link, document or support summary uses the system share sheet only after you choose to share. Still can keep the screen awake during an active session if you enable that preference. It releases that request when stopped or backgrounded. Optional haptics use supported device hardware without collecting interaction statistics.

## 7. Retention, caches and local wipe

Preferences remain until changed, wiped or removed with the app, subject to operating-system backup and restore behavior. The queue, timer and current session are memory-only app state. Stopping the receiver revokes its token and closes its connections; backgrounding also ends whole-screen reception and pauses YouTube. Native direct-stream audio or Picture in Picture may continue when enabled and supported. Stopping a video releases its current player item. Network and system media frameworks may buffer content or maintain caches as part of playback.

“Wipe local data now” first stops receiving and playback, then clears the queue, pairing, timer and app preferences, removes app-managed web data and URL caches, and attempts to delete the app’s cache-directory contents. The interface returns to onboarding. Cleanup may take a short time and displays progress. If file cleanup fails, the app reports that some cached files may remain rather than claiming full success.

Wipe is an app-level reset, not certified forensic erasure. It cannot delete data in another device’s browser, clipboard, screenshot, shared message, provider account, router, OS diagnostic record or existing backup. Another browser may retain previously displayed titles or form input. Stop sharing and clear that browser independently if needed. Uninstalling Still removes its normal app container under iOS rules; restoring a backup may restore older preferences.

## 8. Support, rights and safeguards

A support summary is generated only when you choose to share it. It contains the app version, OS version and generic receiver/playback status. It excludes your receiver name, Wi-Fi address, token, media URLs and titles. Review the system sharing destination yourself. No support report is automatically uploaded.

Depending on applicable law, you may have rights concerning information you voluntarily provide to the developer or a service provider. Contact the developer through the profile above for developer-held communications, and contact the relevant provider for provider-held playback data. Because Still has no account or telemetry database, it cannot identify or delete a server-side playback record that it never received. Provide only information necessary for your request.

Access tokens and input validation reduce accidental exposure but cannot guarantee perfect security. Report a suspected issue privately through available developer contact channels when possible. Avoid placing private credentials in public issues.

## 9. Children, international services and policy changes

Still is a general-purpose playback tool and does not knowingly collect children’s personal information for developer telemetry. A parent or guardian should supervise content access, network sharing and use of third-party services where appropriate. Follow provider age requirements and applicable local rules.

Choosing online media or an external support site may involve service providers operating in other countries. Still does not upload analytics. An optional screen-sharing connection or TURN service may operate internationally; choose its operator knowingly. Policies of those providers govern their processing.

Future versions may change preferences or features. Material changes to this policy will be reflected in the bundled text and its effective/version information. This release contains no consent switch that secretly enables telemetry. Offline copies let you review the policy shipped with your installed version, even if the repository later changes.

## 10. Optional whole-screen connections

Screen-sharing mode uses the HTTPS connection service configured on the receiving device. The developer supplies service source code but no hosted endpoint is preconfigured. The service exchanges a temporary room identifier, a private receiver-owner credential, an invitation credential, recording permission, session descriptions and ICE candidates. Session descriptions and candidates can reveal network addresses and device/media capabilities to the operator and the other peer. TLS protects signaling in transit to the operator; it does not hide these fields from that operator.

The supplied service keeps room state in memory, limits a session to two hours, retains a disconnected receiver briefly for reconnection, and clears room state when it ends or the process restarts. It adds no analytics or access-log feature. Infrastructure, reverse proxies, hosting providers or a customized deployment may create their own operational records. There is no promise that another operator follows this configuration.

WebRTC encrypts screen video in transit. Media travels directly between peers when possible; a configured TURN service can carry the encrypted media when network paths require it. The TURN operator can observe endpoints, timing and traffic volume. STUN services process network-discovery requests. These services are not automatically chosen from public providers in the supplied configuration. You decide which operator to trust; the app cannot guarantee anonymity, perfect security or connectivity on every network.

The Android companion uses the Android system screen-capture consent flow and an ongoing media-projection foreground service with a stop action. Android 13+ may request notification permission for its stop notification; if declined, use the app or Android’s active-app controls to stop. Desktop sending uses the browser’s screen picker. The sender can continue sharing while using other apps where its OS permits, but lock, revocation, battery policy or network changes can stop capture. Camera, microphone and system-audio capture are not implemented in this version. iPhone/iPad whole-screen sending is not implemented. A selected screen can reveal notifications, passwords or private messages; inspect what you share.

## 11. Explicit local screen recordings

The receiver offers recording only for the WebRTC screen feed and only when the supplied sender has opted in before joining. Recording is off by default. A visible recording notice is sent to the sender. This consent control governs the supplied apps; it cannot prevent screenshots, external cameras, modified clients or other recording tools. Obtain any additional permission required by applicable law and by people whose information appears on screen.

Recordings contain screen video only, without audio. They are encoded as local MP4 files, with a 30-minute per-recording limit, bounded frame processing and a low-storage stop. Resolution is capped at a 1280-pixel long edge and the recording frame cadence is capped at 24 fps. Frames may be dropped to keep the player responsive. Protected content may be absent or black. This is not a YouTube downloader, stream-ripping tool or DRM bypass.

Saved recordings persist in Still’s application-support recordings folder until you delete or wipe them. The app marks that folder as excluded from backup; operating-system behavior and copies you export remain outside its control. A recording may include sensitive visible information. It is not automatically uploaded or saved to Photos. Sharing/exporting uses the system share sheet only after your action and needs no photo-library permission. Local Wipe deletes saved recordings after stopping and finalizing an active recording. Wipe cannot recall exported copies, provider records or existing backups. An interrupted save can leave a partial file; app startup attempts to remove incomplete recordings, and wipe removes the recordings folder.

## 12. Background behavior

On the receiving iPhone/iPad, local commands and WebRTC screen reception end when the app enters the background. Active screen recording stops and gets a bounded opportunity to finish saving. The audio background mode is used only for compatible native media playback, not silent audio or a background-server workaround. If you enable Background stream audio, native stream audio can continue under iOS rules. Native Picture in Picture can continue supported video playback after you start it through the player. YouTube is paused when the app backgrounds. iOS may interrupt, suspend or end any session; no setting guarantees indefinite operation.
