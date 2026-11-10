# Design notes

The intended mood is quiet and useful: warm neutral surfaces, system typography, a monochrome primary action, and a single playback area. There are no decorative gradients, looping ambient animations, invented statistics or fake device discovery states. App screens use native SwiftUI navigation, sheets, forms and playback controls. The remote works without external fonts, icon packages or CDN assets.

Motion serves input feedback and service-state changes. Button compression is 2% over 120–140 ms. Service-state transitions use a critically damped 280 ms SwiftUI spring. Reduced Motion disables scale/spring effects, retaining state and opacity feedback. Scrolling, playback time and repeated remote polling do not trigger entrance animations.

Emil’s design-engineering guidance informed short response times, visible keyboard focus, accessible hit targets, restrained motion, and respecting system accessibility preferences. Apple-design guidance informed spatially consistent native sheets, Dynamic Type and native platform controls. The Swift guidance informed concrete value models, an enum for service states and main-actor ownership of UI-facing mutable state. No unmeasured promise of lag-free playback is made.

| Before | After | Why |
| --- | --- | --- |
| Remote screenshot used an arrow glyph that rendered as a missing-font box in Linux Chromium | Removed the decorative glyph from remote buttons and attribution | Keep labels legible without platform font assumptions |
| Browser screenshot retained an input focus ring after fixture setup | Blur the field only during screenshot capture; preserve real keyboard focus styling | Show the resting interface while retaining accessibility |
| Injection test left hostile-looking test text in promotional screenshots | Restore ordinary fixture titles before capturing | Keep test coverage while making previews representative |

The included screenshots show the tested browser remote only. Native appearance and animation still require Xcode previews, simulator and device review.

## 1.1 refinement

The everyday flow remains Start → Scan → Play. Starting from the main screen opens pairing automatically; optional titles and raw pairing URLs sit behind disclosures. Settings groups appearance, playback, sleep, privacy and help so the main screen does not grow with every feature. Queue-only mode is described in ordinary language and gives the remote one clear primary action.

| Before | After | Why |
| --- | --- | --- |
| All settings and legal links shared one long form | A short settings index leads to focused pages | Make each decision easier to find |
| Remote always showed an optional title field | Title lives in an optional disclosure | Shorten the common path to one input |
| Accent choices were absent | Five light/dark adaptive themes also style the paired remote | Personalize without weakening legibility |
| Legal text lived inside the settings view source | Bundled catalog with cross-document and in-page search | Keep long policies offline, navigable and consistent with public copies |
| Queue-only enqueue could use the normal idle-autoplay path | Queue-only adds without starting an idle player | Preserve receiving-user control |
| Cache-file removal would run on the UI actor | Dedicated cache-cleanup actor | Let progress UI remain responsive during filesystem work |

UI tests have been added for onboarding/offline legal access, persistence and local wipe. They await execution on Xcode; browser checks and syntax parsing do not establish native accessibility or frame-time performance.

## 1.2 screen sharing

A single Receive a whole screen entry opens the separate invitation flow. Link controls remain focused on video links. The desktop sender has one primary Choose a screen action, three plain-language quality presets and recording consent off by default. Its active label changes to Sharing screen, with Stop sharing available beneath it. The recording notice remains visible while active. Native recording storage/export lives in a separate library.

| Before | After | Why |
| --- | --- | --- |
| Link sharing was the only transport | A separate screen mode with its own invitation | Keep proprietary casting and actual supported screen transport clear |
| No screen-recording storage | Opt-in local video library with preview, share, delete and wipe | Make recording ownership and retention explicit |
| All playback paused on background | Supported native stream audio/PiP can continue; receivers still stop | Respect platform capabilities without a fake keepalive |
| Signaling-only verification could look successful without media | Real encoded/decoded browser frames tested through loopback TURN/TCP | Verify the transport under the managed browser’s UDP policy |

Screenshots show browser fixtures. Native aesthetics, screen-capture permissions, accessibility and frame-time performance still require device review.
