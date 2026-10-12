# RoachNetiOS

Phone lane for RoachClaw, vault reads, runtime control, and RoachNet Apps installs.

RoachNetiOS keeps the chat surface close, carries RoachTail pairing, and falls back to cached RoachBrain replies when the desktop or internet drops away.

[RoachNet iOS page](https://roachnet.org/ios/)<br>
[IPA release](https://github.com/RoachWares/RoachNet-iOS/releases/latest/download/RoachNetiOS-v0.3.0-unsigned.ipa)<br>
[SideStore / AltStore source](https://raw.githubusercontent.com/RoachWares/RoachNet-SideStore/main/apps.json)<br>
[Sideload notes](./docs/sidestore.md)

## What's new in 0.3.0

- Wears your Mac's theme: with RoachNet 1.1, the companion picks up the theme you chose in Settings › Appearance on the Mac, light themes included. Turn it off under Connection › Appearance.
- The token stays off shared networks: it only travels over HTTPS, inside a tailnet (Tailscale addresses and `*.ts.net` names), or to this device. Plain `http://` to `RoachNet`, a `.local` name or a Wi-Fi address is refused with a note that says why (security review finding I2). The `RoachNet` alias still works in the Simulator on the Mac it points at.
- Face ID, Touch ID or your passcode before Org decisions, changing the token, or forgetting the Mac (finding I8).
- The RoachTail join code on the Runtime tab is hidden until you tap it.
- Bridge URLs with a path (`https://relay.example/roachnet`) keep their path on every request.
- An install the Mac refuses (a pack sent to 1.0.x, an unknown pack, a refused host) shows the Mac's reason instead of sitting in the offline queue. With RoachNet 1.1, theme and speech packs from RoachNet Apps install from the phone.

## What's new in 0.2.0

- A Home tab: your paired Mac's vital signs, quick actions and Org at a glance
- RoachClaw Org on the phone (desktop 1.1+): approve, reject or send back board approvals with a note, pause and resume agents, and join an Org from a `roachnet://org-invite` link
- RoachTail pairing that matches the 1.0.6 desktop (`rtp_` peer tokens), and a pair link that opens straight to "Pair with RoachTail"
- The v4 look: Inter and JetBrains Mono, the floating capsule tab bar, purple for actions and green for live state
- RoachClaw's composer stays above the tab bar and the keyboard, and a paired phone never falls back to preview data when the web catalog is offline
- UI tests that run the app in demo mode and capture every screen
- Security: a `roachnet://pair` link that points at a different Mac, or that carries a token, is confirmed before it is applied and the old token is dropped; install links are confirmed before they reach the Mac; the GPS bridge requires an encrypted Bluetooth link; a privacy manifest is included (build 6)

## What It Does

- Continues RoachClaw chats from the paired desktop lane
- Captures local voice prompts and user-picked images for RoachClaw context
- Reads cached vault and runtime state on the phone
- Keeps an offline-capable RoachBrain fallback when the bridge is down
- Shows runtime health, model state, downloads, and RoachTail status
- Advertises a foreground-only RoachAtlas GPS packet over local BLE when you start it
- Sends RoachNet Apps install intents back to the desktop runtime, and queues them while the Mac is away
- Stays sideload-friendly and open-source friendly with no closed mobile SDKs

## Install

Builds are shipped as unsigned IPAs for SideStore or AltStore, and the preferred install lane is the shared RoachNet AltSource.

```bash
./scripts/build_unsigned_ipa.sh
```

Artifacts:

- `dist/RoachNetiOS-v0.3.0-unsigned.ipa`
- `dist/RoachNetiOS-v0.3.0-unsigned.ipa.sha256`

Install flow:

1. Add the RoachNet source in SideStore or AltStore:
   `https://raw.githubusercontent.com/RoachWares/RoachNet-SideStore/main/apps.json`
2. Install `RoachNetiOS` from the source, or fall back to the IPA if you want the direct file.
3. Let SideStore or AltStore sign it with your Apple ID.
4. Open `RoachNetiOS` and pair the desktop lane.

Full sideload notes live in [docs/sidestore.md](docs/sidestore.md).

## Pairing

The phone app talks to the desktop over the token-gated companion lane and the RoachTail peer-token flow.

Desktop runtime values:

- `ROACHNET_COMPANION_ENABLED=1`
- `ROACHNET_COMPANION_HOST=127.0.0.1` (the bridge binds to loopback only; an HTTPS relay or your tailnet carries it to the phone)
- `ROACHNET_COMPANION_PORT=38111`
- `ROACHNET_COMPANION_TOKEN=<long random token>`

Device values:

- Simulator on the same Mac: `http://RoachNet:38111`
- Real device: the Mac's RoachTail relay (`https://…`) or its tailnet address. 0.3.0 refuses plain `http://` to anything else.

The same install intents used on `apps.roachnet.org` are forwarded through the companion lane into the desktop app.

## RoachAtlas GPS Bridge

The Runtime tab can advertise the iPhone as a local RoachAtlas GPS source for the native desktop receiver.

- BLE service: `E4B29778-2F25-4C70-9B4A-0F9D1D481105`
- GPS characteristic: `E4B29779-2F25-4C70-9B4A-0F9D1D481105`
- Packet: compact JSON with `lat`, `lon`, `accuracy`, `speed`, `course`, `altitude`, `timestamp`, and `source`
- Privacy posture: foreground only, explicit Start/Stop, local Bluetooth transport, no background location mode

## Build

```bash
git clone https://github.com/RoachWares/RoachNet-iOS.git
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

## Tests

```bash
xcodebuild -project RoachNetCompanion.xcodeproj -scheme RoachNetCompanion \
  -sdk iphonesimulator -destination 'platform=iOS Simulator,name=iPhone 17 Pro' \
  CODE_SIGNING_ALLOWED=NO test
```

The UI tests launch the app with `ROACHNET_DEMO_MODE=1`, so no desktop is needed. The live check against a real desktop runtime (pairing, RoachClaw chat, Org join and approval) lives in the RoachNet repo as `npm run smoke:ios-simulator-pairing`.

## Repo Layout

- `RoachNetCompanion/`
  Native SwiftUI app, offline RoachBrain lane, chat, Apps, vault, and runtime views
- `RoachNetCompanionUITests/`
  Demo-mode UI tests with a screenshot of every screen
- `scripts/`
  Xcode project generation and unsigned IPA packaging
- `docs/`
  SideStore, AltStore, and pairing guidance

## License

Apache License 2.0, the same as the RoachNet Mac app. See [LICENSE](LICENSE).
