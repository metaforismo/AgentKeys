import SwiftUI

struct ConnectorSettingsView: View {
    @Bindable var store: AgentStore
    @Environment(\.dismiss) private var dismiss
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @State private var scheme: ConnectorScheme = .https
    @State private var host = ""
    @State private var port = "7777"
    @State private var token = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Mac companion") {
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
                }

                Section {
                    Button("Connect") {
                        guard let value = Int(port), (1...65535).contains(value) else { return }
                        store.configuration = ConnectorConfiguration(scheme: scheme, host: host, port: value, token: token)
                        store.connect()
                        dismiss()
                    }
                    .disabled(host.isEmpty || token.isEmpty || Int(port) == nil)

                    Button("Use interactive demo") {
                        store.useDemo()
                        dismiss()
                    }
                }

                Section("Security") {
                    Text("AgentKeys sends semantic actions only. The companion never accepts arbitrary shell commands from the phone. Prefer HTTPS. Use local HTTP only over loopback or a private Tailscale connection.")
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
            .onAppear {
                scheme = store.configuration.scheme
                host = store.configuration.host
                port = String(store.configuration.port)
                token = store.configuration.token == ConnectorConfiguration.demo.token ? "" : store.configuration.token
            }
        }
    }
}
