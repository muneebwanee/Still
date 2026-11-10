# Validation record · Still 1.2

Validated in the Linux authoring workspace on November 10, 2026:

- Nine Node local-remote tests and five offline-document tests. Public, iOS-bundled, Android-bundled and NCL texts are checked for consistency.
- Eight live-WebSocket relay tests: room authentication, invitation/owner separation, sender cap, offer/answer roles, recording opt-in, receiver resume, TURN REST credentials, foreign-origin rejection, room bounds and malformed input.
- Chromium local-remote integration with an HTTP fixture: pairing, fragment removal, commands, queue, text safety, missing tokens, phone/tablet layouts, themes, reduced motion and queue-only behavior.
- Chromium WebRTC media integration through an isolated loopback coturn TCP relay: actual encoded/decoded video frames between sender and receiver pages, invitation-fragment removal, explicit capture action, video-only request, recording permission/notice, receiver reconnection without recapture, stop cleanup and mobile layout. Capture used a controlled animated canvas, not the real OS screen picker. No public relay was deployed.
- The managed Chromium policy disables non-proxied UDP. Direct-path browser media could not be established here; the TURN/TCP test used the supported fallback without changing that policy. Direct paths still need verification in an appropriate device/network environment.
- All three Android Java source files compiled with Eclipse ECJ against the official Android 36 platform and pinned Android WebRTC/OkHttp/Okio/Kotlin classes. This is source/API compilation, not APK packaging, Android lint, device permission or lifecycle testing.
- Twenty-one Swift files passed tree-sitter syntax parsing. This does not type-check Apple or WebRTC SDK APIs and is not a native build.
- Relay dependency audit: zero reported production vulnerabilities at the time checked, after updating ws to 8.22.2. No audit can guarantee absence of defects.
- Project/workflow/compose YAML, asset/catalog JSON, Android manifest/resource XML, Info.plist, privacy manifest, shell and JavaScript syntax checked.

Authored but not executed here: Swift package tests, two native MP4 recording tests, three iOS UI tests, iOS builds, Android Gradle build/lint and GitHub workflows. No IPA/APK was generated or signed here. Native capture, native recording, PiP, actual background media behavior, performance, accessibility and production HTTPS/TURN deployment need real platform validation.

Screenshots depict browser fixtures, not the native iOS app. No zero-latency, uninterrupted-connection or indefinite iOS background-receiving guarantee is made. See RELEASE.md before distribution.
