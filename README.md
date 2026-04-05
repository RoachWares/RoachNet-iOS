# RoachNet iOS

RoachNet iOS is the chat-first iPhone and iPad companion for the RoachNet desktop runtime.

## What it does

- Continues RoachClaw chats from your Mac
- Reads RoachBrain, vault files, and site archives from the paired install
- Shows runtime health, models, downloads, and service state
- Sends RoachNet Apps installs from the phone back to the Mac runtime

## Pairing

The phone app talks to the Mac over the token-gated companion lane.

Desktop runtime values:

- `ROACHNET_COMPANION_ENABLED=1`
- `ROACHNET_COMPANION_HOST=0.0.0.0`
- `ROACHNET_COMPANION_PORT=38111`
- `ROACHNET_COMPANION_TOKEN=<long random token>`

Phone values:

- `http://<your-mac-ip>:38111`
- the same token

On the simulator, `http://127.0.0.1:38111` is the default so local testing works faster.

## Build

```bash
git clone https://github.com/AHGRoach/RoachNet-iOS.git
cd RoachNet-iOS
ruby scripts/generate_xcodeproj.rb
DEVELOPER_DIR=/Applications/Xcode.app/Contents/Developer xcodebuild \
  -project RoachNetCompanion.xcodeproj \
  -scheme RoachNetCompanion \
  -configuration Debug \
  -sdk iphonesimulator \
  CODE_SIGNING_ALLOWED=NO \
  build
```

## Unsigned IPA

Build an unsigned release IPA for SideStore or AltStore:

```bash
cd RoachNet-iOS
./scripts/build_unsigned_ipa.sh
```

That writes:

- `dist/RoachNetCompanion-v0.1.0-unsigned.ipa`
- `dist/RoachNetCompanion-v0.1.0-unsigned.ipa.sha256`

## Install

Open the IPA in SideStore or AltStore and sign it with your Apple ID. The detailed flow is in [docs/sidestore.md](docs/sidestore.md).

## Pairing notes

- Simulator default: `http://127.0.0.1:38111`
- Real device default: `http://<your-mac-ip>:38111`
- The Mac runtime must have the companion lane enabled with a token
- The same RoachNet Apps install intents used on `apps.roachnet.org` are forwarded through the companion lane into the desktop app

## Repo layout

- `RoachNetCompanion/` native SwiftUI app
- `scripts/` project generation and release packaging
- `docs/` sideloading and pairing notes
