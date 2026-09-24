#!/bin/bash
set -euo pipefail

ROOT_DIR="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT_DIR="$ROOT_DIR/Distribution"
OUTPUT_DIR="$ROOT_DIR/build"

xcodegen generate --spec "$PROJECT_DIR/project.yml" --project "$PROJECT_DIR"
mkdir -p "$OUTPUT_DIR/archives"
rm -rf "$OUTPUT_DIR/archives/IDCardSDK_iOS.xcarchive" \
       "$OUTPUT_DIR/archives/IDCardSDK_Simulator.xcarchive" \
       "$OUTPUT_DIR/IDCardSDK_Core.xcframework"

xcodebuild -quiet archive \
  -project "$PROJECT_DIR/IDCardSDKDistribution.xcodeproj" \
  -scheme IDCardSDK_Core \
  -destination 'generic/platform=iOS' \
  -archivePath "$OUTPUT_DIR/archives/IDCardSDK_iOS.xcarchive" \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO

xcodebuild -quiet archive \
  -project "$PROJECT_DIR/IDCardSDKDistribution.xcodeproj" \
  -scheme IDCardSDK_Core \
  -destination 'generic/platform=iOS Simulator' \
  -archivePath "$OUTPUT_DIR/archives/IDCardSDK_Simulator.xcarchive" \
  SKIP_INSTALL=NO BUILD_LIBRARY_FOR_DISTRIBUTION=YES CODE_SIGNING_ALLOWED=NO

xcodebuild -create-xcframework \
  -framework "$OUTPUT_DIR/archives/IDCardSDK_iOS.xcarchive/Products/Library/Frameworks/IDCardSDK_Core.framework" \
  -framework "$OUTPUT_DIR/archives/IDCardSDK_Simulator.xcarchive/Products/Library/Frameworks/IDCardSDK_Core.framework" \
  -output "$OUTPUT_DIR/IDCardSDK_Core.xcframework"
