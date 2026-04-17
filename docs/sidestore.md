# SideStore install

Use this when you want the RoachNet companion app on an iPhone or iPad without a paid Apple developer account.

## What you need

1. A working SideStore or AltStore setup on the device.
2. The RoachNet SideStore source or the unsigned RoachNet IPA from a GitHub release.
3. A Mac running RoachNet with the companion lane enabled.

## Install with SideStore

1. In Safari on the device, open:
   `https://raw.githubusercontent.com/AHGRoach/RoachNet-SideStore/main/apps.json`
2. Copy or add that source URL inside SideStore.
3. Install `RoachNetiOS` from the source list.
4. If you want the direct file instead, download `RoachNetiOS-v0.1.3-unsigned.ipa` to Files.
5. In SideStore, go to `My Apps`, tap the add button, and pick the IPA from Files.
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
- RoachNet SideStore source: https://raw.githubusercontent.com/AHGRoach/RoachNet-SideStore/main/apps.json
- RoachNet SideStore repo: https://github.com/AHGRoach/RoachNet-SideStore
