# Still 1.2

A quiet screen for shared video. Native SwiftUI for iPhone and iPad, developed by **[muneebwanee](https://github.com/muneebwanee)**. iOS/iPadOS 17+ · Still Non-Commercial License (NCL) 1.0 (source-available).

**Status: implementation ready for Xcode validation; no IPA has been compiled or signed in this Linux workspace.** The local browser remote and browser WebRTC transport have been tested; Android Java source compiled against Android 36. Native iOS compilation, APK assembly, actual capture permissions, YouTube embedding and on-device receiving/recording still need verification. This is not a certified Google Cast receiver.

## What it does

Start Still on an iPhone or iPad, scan its QR code from another device on the same Wi-Fi, then paste a YouTube or compatible HTTPS media link into the browser remote. Playback happens on the receiving iPhone/iPad.

- Start/stop receiver, custom name and Bonjour advertisement using `_stillcast._tcp`.
- QR pairing and system share sheet; fresh random session token on every start.
- Official privacy-enhanced YouTube iframe player; AVPlayer for direct streams.
- Play, pause, seek, next, player volume, native stream full screen and a 20-item queue.
- Automatic queue advance; Auto / 1080p / 720p HLS resolution ceilings where variants exist.
- System/light/dark themes, screen-awake preference, Dynamic Type and Reduce Motion.
- Simple Start → Scan → Play onboarding, guided connection help and optional title fields.
- Five adaptive color themes: Graphite, Moss, Ocean, Clay and Plum; compact layout and optional haptics.
- Sleep timer (15/30/60/90 minutes), supported playback speeds, repeat and configurable skip buttons.
- Native queue editing/reordering, queue-only remotes and disconnect-all session rotation.
- YouTube playback privacy switch, safe manual support summary and immediate stop/revoke followed by local-data cleanup.
- Offline searchable long-form Terms, Zero Developer Telemetry Privacy Policy, Store EULA, Data Safety, NCL 1.0 and credits.
- Separate whole-screen mode: WebRTC iOS receiver, desktop browser sender and Android companion sender.
- Optional internet connections through a deployed HTTPS signaling service and STUN/TURN infrastructure.
- Sender-approved video-only local screen recording, preview, export and deletion.
- Native direct-stream Picture in Picture and optional background audio under iOS rules.
- No accounts, analytics SDK or automatic persistent watch history. WebRTC and its upstream licenses are included for screen mode.

**It does not appear in YouTube’s Cast menu.** Google’s Cast receiver SDK does not support turning an ordinary iOS app into a certified Cast target. Still uses a browser remote and its own receiver protocol. It also does not implement AirPlay receiving or Miracast. A separate WebRTC mode receives screen video from supported computer browsers and the Android companion; it is not a Cast-menu target. Implementing a misleading Cast advertisement would not make YouTube playback work.

Local-link and whole-screen receiving stay in the foreground. Backgrounding stops those receivers and pauses YouTube. Native direct streams may continue supported Picture in Picture or optional background audio; the receivers still stop. The local-link mode requires an IPv4 Wi-Fi address. Use trusted Wi-Fi: the browser remote uses local HTTP, not TLS. A pairing link grants full playback control until the service stops. YouTube and media hosts receive their normal playback requests.

## Upload to GitHub and get an IPA

1. Create a repository and upload **all files from this project**, including the hidden `.github` directory. Keep the folder structure intact. Do not upload this project’s ZIP as a single repository file.
2. Push to `main` or `master`, or open **Actions → Build iOS → Run workflow**.
3. The macOS job runs Swift package tests, browser-remote and document tests, an iOS archive build, a simulator compile and UI tests for onboarding, offline legal access, preference persistence and local wipe.
4. Download the **Still-unsigned** artifact. Inside is `Still-unsigned.ipa`.

An unsigned IPA cannot be installed until it is signed. The workflow has been authored but has not been run from this workspace. No signing credentials are included in the project.

### Signed IPA using GitHub Actions

Obtain an Apple Distribution signing certificate with its private key (`.p12`) and a matching provisioning profile through your Apple Developer account. Register your own bundle ID; the example is `com.muneebwanee.still`.

Add these encrypted **repository Actions secrets**, never source files or chat messages:

| Secret | Value |
| --- | --- |
| `APPLE_TEAM_ID` | Your Apple Developer team ID |
| `IOS_CERTIFICATE_BASE64` | Base64-encoded distribution `.p12` |
| `IOS_CERTIFICATE_PASSWORD` | Password protecting that `.p12` |
| `IOS_PROFILE_BASE64` | Base64-encoded provisioning profile |

Optionally set repository variable `IOS_BUNDLE_ID` to your registered bundle ID. The provisioning profile must match it and your team exactly. Run **Actions → Export signed IPA**. Choose `release-testing` for an ad hoc distribution profile with registered device UDIDs, or `app-store-connect` for an App Store distribution profile. Download **Still-signed**. An App Store export is for TestFlight/App Store upload; an ad hoc export only installs on devices allowed by its profile. This workflow does not publish or submit the app.

### Build locally on a Mac

Install Xcode 16.2+ and XcodeGen, then:

```sh
brew install xcodegen
xcodegen generate
open Still.xcodeproj
```

Choose your team under Signing & Capabilities, set a unique bundle identifier and run on a device. Personal-team development signing may be used locally where Apple permits it. To create an unsigned archive:

```sh
./scripts/build-ipa.sh
```

For an automatic-signing export on a configured Mac:

```sh
SIGNED_BUILD=1 APPLE_TEAM_ID=YOUR_TEAM_ID \
EXPORT_OPTIONS_PLIST=/absolute/path/ExportOptions.plist ./scripts/build-ipa.sh
```

## Permissions

Only **Local Network** access is requested, when starting the receiver. Bonjour service declarations and a usage description are included in `Info.plist`. No camera permission is needed: the sending device scans the displayed QR code using its own camera. No microphone, photo-library, location, contacts, notifications or tracking permissions are requested. iOS owns the permission prompt; the app cannot silently grant itself permission.

## Playback compatibility

YouTube watch, youtu.be, Shorts and live **video** links are normalized to validated video IDs. The official embedded player may reject videos with embedding, age, sign-in, region or owner restrictions. Some environments require a tap on the receiver before playback. YouTube selects its own quality; quality is not forced through an unsupported API. No extraction, downloading, DRM bypass or ad blocking is implemented.

Direct URLs must use HTTPS and end in `.mp4`, `.mov`, `.m4v`, `.mp3`, `.m4a` or `.m3u8` (query strings are supported). Codec support, valid TLS certificates, expiring tokens and HLS variants depend on the media source and iOS. Live streams may have no seekable timeline. Local HTTP media URLs and authenticated/custom-header streams are not supported. Quality ceilings cannot create variants that the stream does not provide.

## Validation

```sh
# Mac / installed Swift toolchain
swift test --package-path Packages/ReceiverCore
# Node 20+
node tests/remote.test.mjs
node tests/documents.test.mjs
(cd relay && npm ci && npm test && npm audit --omit=dev)
# Optional Chromium integration fixture: install Playwright first
node tests/browser.cjs
```

Nine browser-remote logic tests and five offline-document consistency tests passed in this workspace. Chromium integration passed for pairing, address-fragment removal, play/pause, queue, text-injection safety, missing tokens, phone/tablet layouts, light/dark, reduced motion, queue-only mode and receiver theme selection. Integration uses a controlled HTTP fixture and does **not** verify the iOS server or player. `tests/browser.cjs` expects Playwright and `/usr/bin/chromium`; set `CHROMIUM_PATH` for another installation. All Swift files also passed a tree-sitter syntax parse, which is not SDK compilation. Swift tests cover URL acceptance/rejection, fragmented HTTP messages, ambiguous framing, command access policy and saved-speed validation; Swift and iOS UI tests await a macOS/Xcode runner.

[Browser screenshots](docs/screenshots) show the **browser remote**, not a simulator or the native iOS app. See [release validation](docs/RELEASE.md) before distributing.

## Project layout

| Path | Purpose |
| --- | --- |
| `Still/App` | App lifecycle, preferences and foreground behavior |
| `Still/Features` | SwiftUI screens and official YouTube embed |
| `Still/Services` | Network.framework receiver and AVPlayer state |
| `Still/Resources` | Remote page, icon, privacy manifest and app metadata |
| `Packages/ReceiverCore` | URL validation, HTTP parser and command schema |
| `.github/workflows` | macOS validation, unsigned and signed IPA builds |
| `docs` | Public legal text, protocol, design notes and release checks |
| `relay` | HTTPS screen sender, signaling service, TURN templates and socket tests |
| `android-sender` | Android MediaProjection/WebRTC sender companion |
| `StillTests` | Native MP4 recording tests for the macOS/iOS simulator workflow |

[Privacy policy](docs/privacy.md) · [Terms](docs/terms.md) · [Store EULA](docs/eula.md) · [Data safety](docs/dataSafety.md) · [NCL 1.0](docs/ncl.md) · [Compatibility](docs/compatibility.md) · [Protocol](docs/PROTOCOL.md)

Interface guidance: [emilkowalski/skills](https://github.com/emilkowalski/skills), specifically `emil-design-eng`, `apple-design` and `write-swift`, reviewed at commit `715c1807e08c497cfd1dc4feb450a2a3300ef2a9`. Still uses native SwiftUI rather than a web wrapper for its app interface.

## Offline policies and licensing

All nine documents are bundled in `Still/Resources/documents.json`. Settings → Offline legal library works without internet and searches across the six legal/credit documents. Each document also has in-page search, contents navigation and an optional user-directed share sheet. Public Markdown, repository LICENSE and bundled text are generated from `scripts/write-documents.py`; run it after policy edits, then run the document tests. The source and bundled NCL are identical. It is a **project-specific non-commercial license**, not an OSI-approved open-source license. Previously distributed copies keep their original license grants.

The Store EULA includes the required allocation of Apple/developer responsibilities, but the distributor’s actual legal name, mailing address, telephone and contact details must be supplied before a custom store EULA can be treated as submission-ready. This project does not invent those details. Its release remains subject to legal and store review.

## Local wipe

Settings → Privacy & data → Wipe local data now asks once because the action resets preferences and cannot be undone. Receiving and playback stop and the token is revoked before cleanup begins. The app clears memory state, timer, preferences, web data and app caches, then returns to onboarding; cache-file errors are reported. App-level wipe does not erase provider logs, other devices, old backups or OS-managed records. See the bundled Data Safety page. The YouTube switch prevents new YouTube loads and removes YouTube queue entries, while direct media still contacts its provider.

Queue-only mode is enforced on the receiver. A guest can enqueue a video but cannot start an idle player, replace the current video, seek, pause, stop, skip or change volume. Native controls and auto-next remain under the receiving user’s control. Paired guests can still see titles. All local-link remotes are revoked together when you disconnect, stop, background or wipe. Screen-mode service revocation includes a bounded reconnect/expiry grace if an end message cannot be delivered.

## Whole-screen sharing and distance

See [the screen-sharing guide](docs/SCREEN-SHARING.md). After one-time operator setup, the flow is Receive a whole screen → Create invitation → Open on sender → Choose screen. Android uses the separate [Still Sender companion](android-sender/README.md); compatible computer browsers use the [HTTPS sender page](relay/README.md). There is no iPhone/iPad whole-screen sender in this release. Sharing/recording is screen-video-only, without microphone or system audio.

The [connection service](relay/) and TURN templates are supplied as source, not as a running public service. Deploy HTTPS, configure STUN/TURN and set the service origin in the receiver before expecting cross-network sharing. Hosting, TLS certificates, firewall configuration and relay bandwidth remain your operator’s responsibility. The server is not silently deployed from this chat. Local and distant sharing use the same invitation once configured.

The **Build Android sender** workflow produces a test APK after its Gradle/lint checks; **Test screen connection service** runs relay tests and a browser media test. Neither workflow has been run from this workspace. The screen browser test uses a canvas capture fixture and actual WebRTC; testing here used a loopback TURN/TCP server because managed Chromium blocks non-proxied UDP. Actual Android projection, real desktop screen picker and native iOS rendering still need device validation.

Screen recordings are opt-in per sender, video-only, local MP4s capped at 30 minutes / 1280-pixel long edge / 24 fps, with low-storage handling. Local Wipe deletes recordings. Exports are user-directed; exported copies cannot be recalled. See the updated offline Privacy and Data Safety documents for connection metadata, provider processing and backup/erasure limits.

There is no promise of zero delay, an unbreakable connection, unlimited relay bandwidth or an always-on iOS background receiver. The implementation includes quality profiles, WebRTC transport recovery and bounded reconnect attempts. iOS background audio is used for actual compatible native stream playback, not a silent keepalive. Review export-compliance answers for the new third-party WebRTC encryption before App Store submission; the source does not assert a legal encryption exemption.
