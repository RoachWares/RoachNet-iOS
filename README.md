# RoachNet iOS

RoachNet iOS is the chat-first iPhone and iPad companion for the RoachNet desktop runtime.

It keeps the AI lane front and center, so you can continue RoachClaw chats, check runtime state, browse the vault, and push Apps installs back to the Mac from one small mobile surface.

## What it does

- Continues RoachClaw chats from your Mac
- Reads RoachBrain, vault files, and site archives from the paired install
- Shows runtime health, models, downloads, and service state
- Sends RoachNet Apps installs from the phone back to the Mac runtime
- Stays sideload-friendly and open-source friendly with no closed SDK dependencies

## Pairing

The phone app talks to the Mac over the token-gated companion lane.

This `v0.1.0` release targets the companion-enabled RoachNet desktop runtime source lane. The Mac side needs the companion bridge env vars enabled before the phone can pair.

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

## Release notes

`v0.1.0` ships:

- Chat-first iPhone/iPad shell
- RoachClaw session history and local fallback session creation
- Vault summaries for RoachBrain, indexed files, and archives
- Runtime status and service controls
- RoachNet Apps install handoff from phone to desktop
- SideStore / AltStore friendly unsigned IPA packaging

## Repo layout

- `RoachNetCompanion/` native SwiftUI app
- `scripts/` project generation and release packaging
- `docs/` sideloading and pairing notes
