#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/RoachNetCompanion.xcodeproj"
SCHEME="RoachNetCompanion"
VERSION="0.1.2"
BUILD_ROOT="$ROOT/build/release"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
DIST_DIR="$ROOT/dist"
APP_PATH="$BUILD_ROOT/Release-iphoneos/RoachNetCompanion.app"
IPA_PATH="$DIST_DIR/RoachNetiOS-v${VERSION}-unsigned.ipa"
CHECKSUM_PATH="$IPA_PATH.sha256"

ruby "$ROOT/scripts/generate_xcodeproj.rb"
rm -rf "$BUILD_ROOT" "$DIST_DIR"
mkdir -p "$BUILD_ROOT" "$DIST_DIR/Payload"

DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer \
xcodebuild \
  -project "$PROJECT" \
  -scheme "$SCHEME" \
  -configuration Release \
  -sdk iphoneos \
  CODE_SIGNING_ALLOWED=NO \
  CODE_SIGNING_REQUIRED=NO \
  CODE_SIGN_IDENTITY="" \
  -derivedDataPath "$DERIVED_DATA_PATH" \
  BUILD_DIR="$BUILD_ROOT" \
  SYMROOT="$BUILD_ROOT" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app missing at $APP_PATH" >&2
  exit 1
fi

cp -R "$APP_PATH" "$DIST_DIR/Payload/"

(
  cd "$DIST_DIR"
  /usr/bin/zip -qry "$(basename "$IPA_PATH")" Payload
)

rm -rf "$DIST_DIR/Payload"
/usr/bin/shasum -a 256 "$IPA_PATH" | awk '{ print $1 }' > "$CHECKSUM_PATH"

echo "$IPA_PATH"
echo "$CHECKSUM_PATH"
