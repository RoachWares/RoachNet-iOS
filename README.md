<p align="center">
  <img src="https://roachnet.org/assets/readme/roachnet-ios.png" width="100%" alt="RoachNet for iOS: RoachClaw, your vault and your Mac, in your pocket.">
</p>

# RoachNet for iOS

The iPhone and iPad companion to RoachNet on your Mac. The phone is a companion, not a second copy: the models, the Vault and the installs stay on the Mac, and the phone reaches them over your own link.

**RoachNet iOS 0.3.1** · iOS 17 or later · Works with RoachNet 1.0.6 or later on the Mac · [Install guide](https://roachnet.org/docs/get-started/ios/)

## A quick tour

<table>
  <tr>
    <td width="33%"><img src="https://roachnet.org/assets/screens/roachnet-ios-020-home.webp" alt="The companion's Home tab"></td>
    <td width="33%"><img src="https://roachnet.org/assets/screens/roachnet-ios-020-roachclaw.webp" alt="RoachClaw on the phone"></td>
    <td width="33%"><img src="https://roachnet.org/assets/screens/roachnet-ios-020-vault.webp" alt="The Vault on the phone"></td>
  </tr>
  <tr>
    <td><b>Home:</b> the Mac's status, quick actions and the Org at a glance.</td>
    <td><b>RoachClaw:</b> chat with your Mac's models, with voice prompts.</td>
    <td><b>Vault:</b> the Vault and runtime state, cached for when the Mac is out of reach.</td>
  </tr>
</table>

With RoachNet 1.1 the companion also takes Org approvals behind Face ID, Touch ID or your passcode, sends RoachNet Apps installs to the Mac, and follows the theme you picked there.

## Install

The app ships as an unsigned IPA. SideStore or AltStore signs it with your own Apple ID.

1. In SideStore or AltStore, add the RoachNet source:

   ```text
   https://raw.githubusercontent.com/RoachWares/RoachNet-SideStore/main/apps.json
   ```

2. Install **RoachNetiOS** from the source list. Updates show up in the same source.
3. On the Mac, turn on RoachTail and note its join code. On the phone, choose **Pair with RoachTail** and enter it.

Or download the IPA from the [latest release](https://github.com/RoachWares/RoachNet-iOS/releases/latest) and add it under **My Apps**.

> [!NOTE]
> With a free Apple ID, a signature lasts 7 days, so refresh the app in SideStore or AltStore before then. The phone sends its token only over HTTPS, inside a tailnet, or to the device itself.

## What's in this repository

The source of the RoachNet iOS 0.3.1 release: the `RoachNetCompanion` app and its Xcode project. The repository changes with each release. Issues and pull requests are off.

## Help

- **Documentation:** [roachnet.org/docs](https://roachnet.org/docs/) · [Install the iOS companion](https://roachnet.org/docs/get-started/ios/)
- **Something broken, or a security problem?** Email [support@roachwares.org](mailto:support@roachwares.org) with the companion's version and your iOS version. For anything about security, please don't post it in public.

## License

Apache License 2.0. See [LICENSE](LICENSE).

---

<sub>Made by RoachWares LLC. RoachNet · offline on purpose.</sub>
