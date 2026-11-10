# Data Safety & Instant Local Wipe

Version 1.2 · Effective November 10, 2026

## At a glance

Developer telemetry: none. Account: none. Preconfigured developer cloud service: none. Optional screen sharing: configured connection/TURN service. Automatic persistent watch history: none. Explicit screen recordings: local files until deleted. Preferences: on this device. Pairing and queue: memory only. Media playback: connects to the provider you choose. Local remote: HTTP on trusted Wi-Fi.

“Instant” describes stopping playback and revoking pairing immediately when you confirm a wipe. Removing web data and cache files is asynchronous and may take a short time. Still shows progress and reports cleanup errors. This is an app reset, not a certified secure-erasure product.

## 1. What stays where

On this device, Still retains appearance and playback preferences, screen name, privacy choices, background stream-audio choice, configured screen-sharing server address and onboarding status. Explicit screen recordings persist as local MP4 files until deleted or wiped. While running it holds the video link, title, queue, temporary pairing credential and player state in memory. Its timer is a temporary deadline. Playback frameworks and web views may create buffers and caches as part of normal operation.

On a paired sender, the browser can display current and queued titles, video errors and control state. The sender may retain pasted text, browser history, screenshots or clipboard content outside Still’s control. On a media host, provider/network records are subject to that provider’s policy. Still does not have a developer server receiving a duplicate of your queue or playback history.

## 2. Three different reset actions

Stop receiver closes receiving and revokes the current pairing token; it does not delete your preferences or necessarily stop a video already playing on the receiving screen. Disconnect all remotes revokes the token and restarts receiving with a new code while leaving your video in place. Wipe local data now stops both receiving and playback, empties the queue, cancels the timer and resets app-owned data, saved screen recordings and preferences.

Queue-only remotes restrict other devices to adding videos, but do not revoke their session or hide queue titles. Turning YouTube off blocks new YouTube loads, stops an active YouTube player and removes queued YouTube links; it is not a full app wipe. Pick the smallest action that fits what you want to do.

## 3. What the wipe does

After your confirmation, Still first cancels the sleep timer, stops its network listener, closes remote connections and discards its session credential and activity time. It pauses and releases the player item, stops the embedded web page and clears the current video and queue. The app releases its request to keep your display awake.

It then requests deletion of web data from its active transient web store and the app’s default web store, clears the shared URL response cache, and attempts to remove files in its own cache directory. It waits for any active screen recording to finalize, deletes saved recordings, removes the app’s persistent preference domain, restores default playback settings and rebuilds its interface to discard form text and sheet state. You return to the welcome screen. Bundled legal pages, the app binary and installed assets remain so the app still works offline.

The app does not traverse arbitrary personal documents or delete content from other apps. It requests no photo, contact, microphone or file-library permission for this action. An error in cache-file removal is surfaced as a partial-cleanup message; stopping and revoking access has already happened.

## 4. What it cannot wipe

Still cannot delete another device’s browser content, clipboard, shared pairing message, screenshots or downloads. It cannot erase video-provider logs, router records, Apple diagnostics, network-operator records, existing device backups or data you copied elsewhere. A disconnected browser may continue to display previously received text until you close or clear it.

Removing files through iOS APIs does not guarantee overwriting physical flash storage. The operating system may manage snapshots, system media caches or backups outside the app’s direct control. Restoring a backup can restore earlier preferences. For device disposal, use Apple’s device-reset guidance rather than relying on an app-level wipe.

## 5. Safer sharing and recovery

Only pair on Wi-Fi you trust. Keep the full pairing link private. Queue-only mode can reduce disruption when friends send videos; it does not encrypt local traffic. A fresh start creates a new token, and a previously copied link will stop working. If you believe a link has leaked, disconnect all remotes or stop receiving immediately.

If a wipe reports partial cleanup, try again after a restart or uninstall Still to remove its normal container under iOS rules. Configure your OS backup and diagnostics choices separately. If you need support, use the safe summary and inspect its destination before sharing. The summary does not contain a pairing code, media URL, title, network address or your screen name.

## 6. Offline access and verification

All legal, privacy, compatibility and connection-help text is packaged with the app, and can be read and searched without contacting a server. Theme selection, local wipe and local settings do not require an internet account. Online playback still needs the chosen provider; the existence of offline policies does not mean video streaming is offline.

The source repository includes the receiver protocol, tests and release-validation notes. Review those when evaluating the app’s privacy claims. “Zero telemetry” is a statement about developer collection implemented in this version, not a promise that Apple or every third-party media host processes no information. For details, read the full bundled Privacy Policy.

## 7. Screen sharing, recordings and wipe

Whole-screen connections use the configured service and optional STUN/TURN operators, who process connection metadata. Invitations are private bearer credentials. Owner credentials are not included in the sender invitation. Explicitly ending a session requests room revocation; if a device loses connectivity before that request arrives, the supplied service expires disconnected room state after a short grace period and sessions after two hours. Previously delivered data cannot be recalled.

Wipe stops screen receiving and recording as well as the local link receiver. It waits for any active recording to finish, then attempts to remove the recordings directory. If removal fails, it reports that some data may remain. It cannot delete the operator’s independent logs, another device’s state, or exported recordings. Saved recordings are excluded from backup by the app but are still sensitive local files until removed. App-level reset is not physical flash overwrite.
