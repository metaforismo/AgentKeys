import SwiftUI
import VisionKit

/// Live camera scanner for the connector's pairing QR code.
struct PairingScannerView: UIViewControllerRepresentable {
    let onScan: (String) -> Bool

    static var isSupported: Bool {
        DataScannerViewController.isSupported && DataScannerViewController.isAvailable
    }

    func makeUIViewController(context: Context) -> DataScannerViewController {
        let scanner = DataScannerViewController(
            recognizedDataTypes: [.barcode(symbologies: [.qr])],
            qualityLevel: .balanced,
            isGuidanceEnabled: true,
            isHighlightingEnabled: true
        )
        scanner.delegate = context.coordinator
        try? scanner.startScanning()
        return scanner
    }

    func updateUIViewController(_ controller: DataScannerViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan)
    }

    @MainActor
    final class Coordinator: NSObject, DataScannerViewControllerDelegate {
        private let onScan: (String) -> Bool
        private var didDeliver = false

        init(onScan: @escaping (String) -> Bool) {
            self.onScan = onScan
        }

        func dataScanner(
            _ dataScanner: DataScannerViewController,
            didAdd addedItems: [RecognizedItem],
            allItems: [RecognizedItem]
        ) {
            guard !didDeliver else { return }
            for item in addedItems {
                if case .barcode(let barcode) = item, let payload = barcode.payloadStringValue {
                    didDeliver = onScan(payload)
                    if didDeliver { return }
                }
            }
        }
    }
}

/// Sheet wrapper: shows the scanner when the device supports it, and a
/// paste-the-link fallback (simulators, denied camera) when it doesn't.
struct PairingCaptureSheet: View {
    let onPaired: (ConnectorConfiguration) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var rejectedCode = false

    var body: some View {
        NavigationStack {
            Group {
                if PairingScannerView.isSupported {
                    ZStack(alignment: .bottom) {
                        PairingScannerView { payload in
                            handle(payload)
                        }
                        .ignoresSafeArea()

                        Text(rejectedCode
                            ? "That code isn't an AgentKeys pairing QR."
                            : "Point the camera at the QR code in the connector's terminal.")
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 10)
                            .background(.black.opacity(0.65), in: Capsule())
                            .padding(.bottom, 28)
                    }
                } else {
                    ContentUnavailableView(
                        "Camera unavailable",
                        systemImage: "qrcode.viewfinder",
                        description: Text("Scanning isn't available on this device. Copy the agentkeys:// link from the connector's terminal and use “Paste pairing link” instead.")
                    )
                }
            }
            .navigationTitle("Scan to pair")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
        }
    }

    private func handle(_ payload: String) -> Bool {
        if let configuration = PairingLink.parse(payload) {
            onPaired(configuration)
            dismiss()
            return true
        }
        rejectedCode = true
        return false
    }
}
