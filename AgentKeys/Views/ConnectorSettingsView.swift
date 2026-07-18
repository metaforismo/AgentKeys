import SwiftUI
import UIKit

struct ConnectorSettingsView: View {
    @Bindable var store: AgentStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var scheme: ConnectorScheme = .https
    @State private var host = ""
    @State private var port = "7777"
    @State private var token = ""
    @State private var isScannerPresented = false
    @State private var pasteFeedback: String?

    var body: some View {
        NavigationStack {
            Form {
                Section("Connection") {
                    HStack(spacing: 10) {
                        DeckLED(color: statusColor, size: 9)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(store.connectionState.label)
                                .font(.subheadline.weight(.semibold))
                            Text(statusDetail)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                        }
                    }
                }

                Section {
                    Button {
                        isScannerPresented = true
                    } label: {
                        Label("Scan pairing QR", systemImage: "qrcode.viewfinder")
                    }

                    Button {
                        pastePairingLink()
                    } label: {
                        Label("Paste pairing link", systemImage: "doc.on.clipboard")
                    }

                    if let pasteFeedback {
                        Text(pasteFeedback)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Pair with your Mac")
                } footer: {
                    Text("Run the connector on your Mac (npm start in connector/). It prints a QR code and an agentkeys:// link that fill everything in below.")
                }

                Section("Manual setup") {
                    Picker("Transport", selection: $scheme) {
                        ForEach(ConnectorScheme.allCases, id: \.self) { option in
                            Text(option.label).tag(option)
                        }
                    }
                    TextField("Tailscale IP or hostname", text: $host)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    TextField("Port", text: $port)
                        .keyboardType(.numberPad)
                    SecureField("Pairing token", text: $token)
                        .textInputAutocapitalization(.never)

                    Button("Connect") {
                        guard let value = Int(port), (1...65535).contains(value) else { return }
                        store.apply(pairing: ConnectorConfiguration(scheme: scheme, host: host, port: value, token: token))
                        dismiss()
                    }
                    .disabled(host.isEmpty || token.isEmpty || Int(port) == nil)
                }

                Section {
                    Button("Use interactive demo") {
                        store.useDemo()
                        dismiss()
                    }

                    if store.hasStoredConnector {
                        Button("Forget this Mac", role: .destructive) {
                            store.forgetConnector()
                            host = ""
                            token = ""
                        }
                    }
                }

                Section("Security") {
                    Text("AgentKeys sends semantic actions only. The companion never accepts arbitrary shell commands from the phone. The pairing token is stored in the iOS Keychain. Prefer HTTPS; use local HTTP only over loopback or a private Tailscale connection.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }

                Section("Help") {
                    Button("Replay introduction") {
                        hasCompletedOnboarding = false
                        dismiss()
                    }
                }
            }
            .navigationTitle("Connector")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $isScannerPresented) {
                PairingCaptureSheet { configuration in
                    store.apply(pairing: configuration)
                    dismiss()
                }
            }
            .onAppear {
                scheme = store.configuration.scheme
                host = store.configuration == .demo ? "" : store.configuration.host
                port = String(store.configuration.port)
                token = store.configuration == .demo ? "" : store.configuration.token
            }
        }
    }

    private func pastePairingLink() {
        guard let text = UIPasteboard.general.string else {
            pasteFeedback = "The clipboard is empty."
            return
        }
        guard let configuration = PairingLink.parse(text) else {
            pasteFeedback = "That isn't an agentkeys:// pairing link."
            return
        }
        store.apply(pairing: configuration)
        dismiss()
    }

    private var statusColor: Color {
        switch store.connectionState {
        case .demo: .orange
        case .connecting: .blue
        case .connected: .green
        case .failed: .red
        }
    }

    private var statusDetail: String {
        switch store.connectionState {
        case .demo:
            return "Offline demo with simulated agents."
        case .connecting:
            return "Reaching \(store.configuration.host):\(store.configuration.port)…"
        case .connected:
            return "\(store.configuration.host):\(store.configuration.port)"
        case .failed(let reason):
            return reason
        }
    }
}
