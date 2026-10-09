import SwiftUI
import VisionKit

struct ConnectionSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var model: CompanionAppModel
    @State private var scannerPresented = false
    @State private var scannerError: String?

    var body: some View {
        ZStack {
            RoachBackdrop()

            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    RoachHeroPanel(accent: RoachTheme.tertiary) {
                        VStack(alignment: .leading, spacing: 14) {
                            RoachSectionHeader(
                                eyebrow: "Pairing",
                                title: "Link this phone to your Mac.",
                                detail: "Use the companion URL with a RoachTail join code, or paste the full companion token if you already have it."
                            )

                            LazyVGrid(
                                columns: [
                                    GridItem(.flexible(minimum: 0), spacing: 10),
                                    GridItem(.flexible(minimum: 0), spacing: 10),
                                ],
                                alignment: .leading,
                                spacing: 10
                            ) {
                                RoachSignalTile(
                                    label: "Bridge",
                                    value: model.connection.isConfigured ? "Configured" : "Waiting",
                                    accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary,
                                    systemImage: "link"
                                )
                                RoachSignalTile(
                                    label: "Transport",
                                    value: model.connection.securityLabel,
                                    accent: RoachTheme.tertiary,
                                    systemImage: "shield.lefthalf.filled"
                                )
                                RoachSignalTile(
                                    label: "RoachTail",
                                    value: model.usingRoachTailPeerToken ? "Peer token" : "Join code",
                                    accent: RoachTheme.secondary,
                                    systemImage: "point.3.connected.trianglepath.dotted"
                                )
                                RoachSignalTile(
                                    label: "Account",
                                    value: model.runtime?.account?.linked == true ? "Linked" : "Local",
                                    accent: model.runtime?.account?.linked == true ? RoachTheme.primary : RoachTheme.tertiary,
                                    systemImage: "person.crop.circle"
                                )
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Companion URL")
                                    .font(RoachType.caption(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)

                                TextField("http://RoachNet:38111", text: $model.connection.baseURL)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(RoachTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("RoachTail join code")
                                    .font(RoachType.caption(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)

                                TextField("ROACH-ABCDE-12345", text: $model.connection.pairCode)
                                    .textInputAutocapitalization(.characters)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(RoachTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))

                                if let scannerError, !scannerError.isEmpty {
                                    Text(scannerError)
                                        .font(RoachType.caption)
                                        .foregroundStyle(RoachTheme.primary)
                                }
                            }

                            VStack(alignment: .leading, spacing: 8) {
                                Text("Companion token")
                                    .font(RoachType.caption(.semibold))
                                    .foregroundStyle(RoachTheme.subduedText)

                                SecureField("Paste the RoachNet companion token", text: $model.connection.token)
                                    .textInputAutocapitalization(.never)
                                    .autocorrectionDisabled()
                                    .padding(12)
                                    .background(RoachTheme.elevatedSurface, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
                            }
                        }
                    }

                    RoachPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            RoachSectionHeader(
                                eyebrow: "What it opens",
                                title: "Chat, vault, runtime, and installs.",
                                detail: "The same token-gated bridge handles RoachClaw chat, RoachBrain reads, service controls, and Apps installs."
                            )

                            RoachBadge(
                                title: model.connection.isConfigured
                                    ? (model.usingRoachTailPeerToken ? "Paired over RoachTail" : "Configured")
                                    : "Needs setup",
                                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Desktop alias: http://RoachNet:38111")
                                Text("Phone lane: pair over RoachTail instead of targeting a raw IP.")
                                Text(
                                    model.usingRoachTailPeerToken
                                        ? "This iPhone is already using its own RoachTail peer token."
                                        : "Pair once with the join code to mint a private RoachTail bridge token for this device."
                                )
                            }
                            .font(RoachType.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                        }
                    }

                    RoachPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            RoachSectionHeader(
                                eyebrow: "Security",
                                title: model.connection.securityLabel,
                                detail: model.connection.securityDetail
                            )

                            RoachBadge(
                                title: model.connection.isConfigured ? model.connection.securityLabel : "Needs trusted lane",
                                accent: model.connection.isConfigured ? RoachTheme.secondary : RoachTheme.primary
                            )

                            VStack(alignment: .leading, spacing: 6) {
                                Text("RoachNetiOS keeps the chat lane native. There is no embedded browser surface inside the app.")
                                Text("Companion tokens live in the iOS Keychain instead of plain user defaults.")
                                Text("Remote bridges must be HTTPS. Plain HTTP is limited to trusted local RoachNet lanes such as RoachTail, localhost, and private network hosts.")
                            }
                            .font(RoachType.caption)
                            .foregroundStyle(RoachTheme.subduedText)
                        }
                    }

                    RoachPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            RoachSectionHeader(
                                eyebrow: "Account",
                                title: model.accountStatusTitle,
                                detail: model.accountStatusDetail
                            )

                            if let account = model.runtime?.account {
                                RoachBadge(
                                    title: account.linked ? "Linked" : "Local only",
                                    accent: account.linked ? RoachTheme.secondary : RoachTheme.primary
                                )

                                VStack(alignment: .leading, spacing: 6) {
                                    Text("Alias host: \(account.aliasHost)")
                                    if let email = account.email, !email.isEmpty {
                                        Text("Account: \(email)")
                                    }
                                    Text(account.settingsSyncEnabled ? "Settings sync is armed." : "Settings stay local on this phone right now.")
                                    Text(account.savedAppsSyncEnabled ? "Saved app picks can follow the account lane." : "Saved app picks stay local until sync is armed.")
                                    Text(account.hostedChatEnabled ? "Hosted RoachClaw is allowed for this account." : "Hosted RoachClaw is off for this account.")
                                }
                                .font(RoachType.caption)
                                .foregroundStyle(RoachTheme.subduedText)

                                if !account.notes.isEmpty {
                                    VStack(alignment: .leading, spacing: 6) {
                                        ForEach(account.notes.prefix(3), id: \.self) { note in
                                            Text(note)
                                        }
                                    }
                                    .font(RoachType.caption)
                                    .foregroundStyle(RoachTheme.subduedText)
                                }
                            } else {
                                VStack(alignment: .leading, spacing: 6) {
                                    Text("The website lane is where account auth, hosted RoachClaw, and future synced settings live.")
                                    Text("Desktop data still stays grouped inside the contained RoachNet folder and the RoachTail/RoachSync lanes.")
                                }
                                .font(RoachType.caption)
                                .foregroundStyle(RoachTheme.subduedText)
                            }

                            HStack(spacing: 10) {
                                Link(destination: CompanionAppModel.accountPortalURL) {
                                    Text("Open account lane")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RoachButtonStyle(kind: .primary, size: .compact))
                                .tint(RoachTheme.primary)

                                Link(destination: CompanionAppModel.apiDocsURL) {
                                    Text("API docs")
                                        .frame(maxWidth: .infinity)
                                }
                                .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                                .tint(RoachTheme.secondary)
                            }
                        }
                    }

                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 12) {
                            Button("Scan QR") {
                                scannerError = nil
                                scannerPresented = true
                            }
                            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                            .tint(RoachTheme.tertiary)

                            Button("Pair with RoachTail") {
                                Task {
                                    await model.pairWithRoachTail()
                                    if model.connection.isConfigured {
                                        dismiss()
                                    }
                                }
                            }
                            .buttonStyle(RoachButtonStyle(kind: .signal, size: .compact))
                            .tint(RoachTheme.secondary)

                            Button("Save & Test") {
                                Task {
                                    model.connection.save()
                                    await model.refreshAll()
                                    dismiss()
                                }
                            }
                            .buttonStyle(RoachButtonStyle(kind: .primary, size: .compact))
                            .tint(RoachTheme.primary)

                            Button("Refresh") {
                                Task {
                                    await model.refreshAll()
                                }
                            }
                            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                            .tint(RoachTheme.secondary)
                        }

                        VStack(spacing: 10) {
                            Button("Scan QR") {
                                scannerError = nil
                                scannerPresented = true
                            }
                            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                            .tint(RoachTheme.tertiary)

                            Button("Pair with RoachTail") {
                                Task {
                                    await model.pairWithRoachTail()
                                    if model.connection.isConfigured {
                                        dismiss()
                                    }
                                }
                            }
                            .buttonStyle(RoachButtonStyle(kind: .signal, size: .compact))
                            .tint(RoachTheme.secondary)

                            Button("Save & Test") {
                                Task {
                                    model.connection.save()
                                    await model.refreshAll()
                                    dismiss()
                                }
                            }
                            .buttonStyle(RoachButtonStyle(kind: .primary, size: .compact))
                            .tint(RoachTheme.primary)

                            Button("Refresh") {
                                Task {
                                    await model.refreshAll()
                                }
                            }
                            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                            .tint(RoachTheme.secondary)
                        }
                    }

                    RoachPanel {
                        VStack(alignment: .leading, spacing: 12) {
                            RoachSectionHeader(
                                eyebrow: "Reset",
                                title: "Forget this Mac lane.",
                                detail: "Clear the companion token, RoachTail join code, and desktop bridge details from this phone."
                            )

                            Button("Forget linked Mac") {
                                model.clearConnection()
                                dismiss()
                            }
                            .buttonStyle(RoachButtonStyle(kind: .secondary, size: .compact))
                            .tint(RoachTheme.primary)
                        }
                    }
                }
                .padding(18)
            }
        }
        .navigationTitle("Connection")
        .sheet(isPresented: $scannerPresented) {
            NavigationStack {
                Group {
                    if RoachTailScannerView.isAvailable {
                        RoachTailScannerView { payload in
                            model.applyRoachTailPairingPayload(payload)
                            scannerPresented = false
                        } onFailure: { message in
                            scannerError = message
                            scannerPresented = false
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 16) {
                            Text("QR scanning is not available on this device right now.")
                                .font(RoachType.headline())
                                .foregroundStyle(RoachTheme.text)
                            Text("Paste the bridge URL and RoachTail join code manually, or retry on a camera-capable device.")
                                .font(RoachType.body)
                                .foregroundStyle(RoachTheme.subduedText)
                            Button("Close") {
                                scannerPresented = false
                            }
                            .buttonStyle(RoachButtonStyle(kind: .signal, size: .compact))
                            .tint(RoachTheme.secondary)
                        }
                        .padding(24)
                        .background(RoachBackdrop())
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Done") {
                            scannerPresented = false
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
        }
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button("Done") {
                    dismiss()
                }
            }
        }
    }
}

@available(iOS 16.0, *)
private struct RoachTailScannerView: UIViewControllerRepresentable {
    static var isAvailable: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    let onPayload: (String) -> Void
    let onFailure: (String) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(onPayload: onPayload, onFailure: onFailure)
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let controller = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            recognizesMultipleItems: false,
            isHighFrameRateTrackingEnabled: false,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        controller.delegate = context.coordinator

        do {
            try controller.startScanning()
        } catch {
            context.coordinator.fail("RoachNetiOS could not start the QR scanner.")
        }

        return controller
    }

    func updateUIViewController(_ uiViewController: DataScannerViewController, context: Context) {}

    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onPayload: (String) -> Void
        private let onFailure: (String) -> Void
        private var hasDeliveredResult = false

        init(onPayload: @escaping (String) -> Void, onFailure: @escaping (String) -> Void) {
            self.onPayload = onPayload
            self.onFailure = onFailure
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !hasDeliveredResult else { return }

            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue, !payload.isEmpty {
                    hasDeliveredResult = true
                    onPayload(payload)
                    return
                }
            }
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            becameUnavailableWithError error: DataScannerViewController.ScanningUnavailable
        ) {
            fail("RoachNetiOS lost access to the QR scanner.")
        }

        func fail(_ message: String) {
            guard !hasDeliveredResult else { return }
            hasDeliveredResult = true
            onFailure(message)
        }
    }
}
