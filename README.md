# RoachNetiOS

Phone lane for RoachClaw, vault reads, runtime control, and RoachNet Apps installs.

RoachNetiOS keeps the chat surface close, carries RoachTail pairing, and falls back to cached RoachBrain replies when the desktop or internet drops away.

[RoachNet iOS page](https://roachnet.org/iOS/)<br>
[IPA release](https://github.com/AHGRoach/RoachNet-iOS/releases/latest/download/RoachNetiOS-v0.1.4-unsigned.ipa)<br>
[SideStore source](https://raw.githubusercontent.com/AHGRoach/RoachNet-SideStore/main/apps.json)<br>
[SideStore notes](./docs/sidestore.md)

## What It Does

- Continues RoachClaw chats from the paired desktop lane
- Reads cached vault and runtime state on the phone
- Keeps an offline-capable RoachBrain fallback when the bridge is down
- Shows runtime health, model state, downloads, and RoachTail status
- Sends RoachNet Apps install intents back to the desktop runtime
- Stays sideload-friendly and open-source friendly with no closed mobile SDKs

## Install

Builds are shipped as unsigned IPAs for SideStore or AltStore, and the preferred install lane is now the RoachNet SideStore source.

```bash
./scripts/build_unsigned_ipa.sh
```

Artifacts:

- `dist/RoachNetiOS-v0.1.4-unsigned.ipa`
- `dist/RoachNetiOS-v0.1.4-unsigned.ipa.sha256`

Install flow:

1. Add the RoachNet source in SideStore:
   `https://raw.githubusercontent.com/AHGRoach/RoachNet-SideStore/main/apps.json`
2. Install `RoachNetiOS` from the source, or fall back to the IPA if you want the direct file.
3. Let SideStore or AltStore sign it with your Apple ID.
4. Open `RoachNetiOS` and pair the desktop lane.

Full sideload notes live in [docs/sidestore.md](docs/sidestore.md).

## Pairing

The phone app talks to the desktop over the token-gated companion lane and the RoachTail peer-token flow.

Desktop runtime values:

- `ROACHNET_COMPANION_ENABLED=1`
- `ROACHNET_COMPANION_HOST=0.0.0.0`
- `ROACHNET_COMPANION_PORT=38111`
- `ROACHNET_COMPANION_TOKEN=<long random token>`

Device values:

- Desktop alias: `http://RoachNet:38111`
- Real device: pair over RoachTail or use the companion bridge URL the Mac advertises

The same install intents used on `apps.roachnet.org` are forwarded through the companion lane into the desktop app.

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

## Repo Layout

- `RoachNetCompanion/`
  Native SwiftUI app, offline RoachBrain lane, chat, Apps, vault, and runtime views
- `scripts/`
  Xcode project generation and unsigned IPA packaging
- `docs/`
  SideStore notes and pairing guidance
