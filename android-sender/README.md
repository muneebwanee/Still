# Still Sender · Android companion

Android 10+ screen-video sender for Still’s WebRTC receiver. A separate Android app is necessary because Android browsers generally do not provide desktop-style `getDisplayMedia` capture. iPhone/iPad whole-screen sending is not supplied.

Open the receiver’s HTTPS invitation in a browser, then choose **Open Android sender**, or paste the complete invitation into the companion. Choose a quality profile and optionally allow receiver recording, then approve Android’s system screen-capture dialog. Anything visible on the chosen screen can be transmitted. Protected apps can block capture; this app does not bypass that restriction.

Capture runs in an Android media-projection foreground service with a visible stop notification. Use other apps while sharing where Android allows it. The system can stop capture on lock, permission revocation or resource restrictions. Closing the task stops this service. The app uses no camera, microphone or system-audio track. The receiving iPhone/iPad must stay open.

No analytics, stored invitation history or backend account is included. The app disables Android backup. Its connection service, STUN/TURN provider, the network and OS can process operational metadata. Screen video is encrypted by WebRTC. Recording permission is off by default; when enabled, the receiver can save screen video and sends a visible recording notice. This cannot prevent external capture.

## Build

Use Android Studio with Android SDK 36 and Java 17, or the supplied **Build Android sender** GitHub Actions workflow. That workflow installs Gradle 8.13, builds and lints a debug APK, then uploads `Still-Sender-debug`. Debug builds are for testing; configure your own signing/keystore, distribution metadata and store-policy review before releasing.

```sh
gradle --no-daemon assembleDebug lintDebug
```

This directory deliberately contains no private signing material. It has no Gradle wrapper; use the pinned Gradle version configured by CI or a matching local installation.

Source compilation against Android 36/WebRTC was checked in the authoring workspace with ECJ. A full Gradle APK build, Android lint, system capture permission flow, foreground-service lifecycle, lock, rotation and real Android-to-iOS streaming remain to be verified. The CI workflow has been authored but not executed here.

Dependencies: Android WebRTC `150.7871.04`, OkHttp `4.12.0` and their transitives, under their respective licenses. The project NCL applies only to app-authored material, not these third-party packages. Notices are included in the app resources; review transitive notices for a release artifact.
