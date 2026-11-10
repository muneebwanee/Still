#!/bin/bash
set -euo pipefail
cd "$(dirname "$0")/.."
command -v xcodegen >/dev/null || { echo 'Install XcodeGen: brew install xcodegen'; exit 1; }
xcodegen generate
mkdir -p build
if [[ "${SIGNED_BUILD:-0}" == "1" ]]; then
  : "${APPLE_TEAM_ID:?Set APPLE_TEAM_ID}"
  : "${EXPORT_OPTIONS_PLIST:?Set EXPORT_OPTIONS_PLIST to your export options file}"
  xcodebuild -project Still.xcodeproj -scheme Still -configuration Release -destination 'generic/platform=iOS' -archivePath build/Still.xcarchive DEVELOPMENT_TEAM="$APPLE_TEAM_ID" -allowProvisioningUpdates archive
  xcodebuild -exportArchive -archivePath build/Still.xcarchive -exportPath build/signed -exportOptionsPlist "$EXPORT_OPTIONS_PLIST" -allowProvisioningUpdates
else
  xcodebuild -project Still.xcodeproj -scheme Still -configuration Release -destination 'generic/platform=iOS' -archivePath build/Still.xcarchive CODE_SIGNING_ALLOWED=NO archive
  artifact="$PWD/build/Still-unsigned.ipa"
  rm -f "$artifact"
  stage=$(mktemp -d)
  trap 'rm -rf "$stage"' EXIT
  mkdir -p "$stage/Payload"
  cp -R build/Still.xcarchive/Products/Applications/Still.app "$stage/Payload/"
  (cd "$stage" && /usr/bin/zip -qry "$artifact" Payload)
  echo 'Created build/Still-unsigned.ipa. This must be signed before installation.'
fi
