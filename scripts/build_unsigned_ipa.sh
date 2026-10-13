#!/bin/zsh
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
PROJECT="$ROOT/RoachNetCompanion.xcodeproj"
SCHEME="RoachNetCompanion"
VERSION="0.3.1"
BUILD_ROOT="$ROOT/build/release"
DERIVED_DATA_PATH="$BUILD_ROOT/DerivedData"
DIST_DIR="$ROOT/dist"
APP_PATH="$BUILD_ROOT/Release-iphoneos/RoachNetCompanion.app"
IPA_PATH="$DIST_DIR/RoachNetiOS-v${VERSION}-unsigned.ipa"
CHECKSUM_PATH="$IPA_PATH.sha256"

if [[ "${ROACHNET_REGENERATE_XCODEPROJ:-0}" == "1" ]]; then
  ruby "$ROOT/scripts/generate_xcodeproj.rb"
fi
# Keep earlier versions' IPAs in dist/; only replace this version's outputs.
rm -rf "$BUILD_ROOT" "$DIST_DIR/Payload" "$IPA_PATH" "$CHECKSUM_PATH"
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
  OBJROOT="$BUILD_ROOT/Intermediates" \
  build

if [[ ! -d "$APP_PATH" ]]; then
  echo "Expected app missing at $APP_PATH" >&2
  exit 1
fi

cp -R "$APP_PATH" "$DIST_DIR/Payload/"

# Drop the debug map from every executable: it holds absolute paths from the
# build Mac (its volume and workspace folders). dSYMs stay in $BUILD_ROOT.
find "$DIST_DIR/Payload" -type f -perm +111 | while IFS= read -r binary; do
  if /usr/bin/file -b "$binary" | grep -q "Mach-O"; then
    xcrun strip -S "$binary" 2>/dev/null
  fi
done

# Refuse to package anything that still names this Mac's folders or host name.
LOCAL_HOST="$(scutil --get LocalHostName 2>/dev/null || true)"
NEEDLES=(-e "$ROOT" -e "$HOME/")
if (( ${#LOCAL_HOST} >= 4 )) && [[ "${LOCAL_HOST:l}" != *roach* ]]; then NEEDLES+=(-e "$LOCAL_HOST"); fi
if LC_ALL=C grep -rqaiF "${NEEDLES[@]}" "$DIST_DIR/Payload"; then
  echo "The app still carries this Mac's paths or host name; not packaging it." >&2
  rm -rf "$DIST_DIR/Payload"
  exit 1
fi

(
  cd "$DIST_DIR"
  /usr/bin/zip -qry "$(basename "$IPA_PATH")" Payload
)

rm -rf "$DIST_DIR/Payload"
/usr/bin/shasum -a 256 "$IPA_PATH" | awk '{ print $1 }' > "$CHECKSUM_PATH"

echo "$IPA_PATH"
echo "$CHECKSUM_PATH"
