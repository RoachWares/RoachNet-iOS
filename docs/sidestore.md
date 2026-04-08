# SideStore install

Use this when you want the RoachNet companion app on an iPhone or iPad without a paid Apple developer account.

## What you need

1. A working SideStore or AltStore setup on the device.
2. The unsigned RoachNet IPA from a GitHub release, or one you built locally with `./scripts/build_unsigned_ipa.sh`.
3. A Mac running RoachNet with the companion lane enabled.

## Install with SideStore

1. Download `RoachNetiOS-v0.1.2-unsigned.ipa` to Files on the device.
2. Open `SideStore`.
3. Go to `My Apps`.
4. Tap the add button.
5. Pick the RoachNet IPA from Files.
6. Let SideStore sign and install it with your Apple ID.

## First launch

1. Open `RoachNet`.
2. Paste the companion URL from your Mac.
3. Paste the companion token from your Mac.
4. Tap `Save`.
5. Refresh once if the runtime is still warming up.

## Pairing tips

- Use the `http://RoachNet:38111` desktop alias when it is available locally, or pair over RoachTail for the secure device lane.
- Keep the phone and Mac on the same network unless you have your own secure tunnel in front of the companion port.
- Do not expose the companion token publicly.
- If installs from the Apps catalog fail, verify the paired Mac runtime is healthy first.
- The iOS app is just the companion surface. The real models, vault, and installs still live on the paired RoachNet desktop.

## Notes

- Free Apple accounts still inherit Apple’s normal sideload limits.
- Reinstalling the same IPA through SideStore should preserve app data in normal cases.
- SideStore documentation: https://docs.sidestore.io/
