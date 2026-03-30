import SwiftUI
import FoundationModels

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var testStatus: TestStatus = .idle
    @State private var localAvailable: Bool = false

    private var gateway: GatewayConfig { appState.gatewayConfig }

    var body: some View {
        NavigationStack {
            ZStack {
                AdaptiveBackground(style: .study)

                List {
                    intelligenceSection
                    gatewaySection
                    aboutSection
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Settings")
            .task { checkLocalModel() }
        }
    }

    // MARK: - Intelligence section

    private var intelligenceSection: some View {
        Section {
            // Local model status
            HStack {
                Label("On-Device AI", systemImage: "lock.fill")
                Spacer()
                if localAvailable {
                    Label("Available", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundStyle(.green)
                        .labelStyle(.titleAndIcon)
                } else {
                    Text("Unavailable")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            // Cloud gateway status
            HStack {
                Label("Cloud Gateway", systemImage: "cloud.fill")
                Spacer()
                Text(gateway.isConfigured ? "Configured" : "Not set up")
                    .font(.caption)
                    .foregroundStyle(gateway.isConfigured ? .green : .orange)
            }
        } header: {
            Text("Intelligence")
        } footer: {
            Text(localAvailable
                ? "On-device AI is active. Cloud gateway provides a fallback for complex tasks."
                : "Apple Intelligence is not available on this device. Configure a Cloud Gateway below to enable AI features.")
        }
        .listRowBackground(glassRowBackground)
    }

    // MARK: - Gateway section

    @ViewBuilder
    private var gatewaySection: some View {
        Section {
            // Base URL
            @Bindable var gw = gateway
            HStack {
                Label("Gateway URL", systemImage: "network")
                    .layoutPriority(1)
                TextField("https://ai.yourdomain.com", text: $gw.baseURL)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .keyboardType(.URL)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

            // API Key
            HStack {
                Label("API Key", systemImage: "key.fill")
                    .layoutPriority(1)
                SecureField("sk-...", text: $gw.apiKey)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .multilineTextAlignment(.trailing)
                    .foregroundStyle(.secondary)
            }

            // Model picker
            Picker(selection: $gw.model) {
                ForEach(GatewayConfig.availableModels, id: \.id) { m in
                    Text(m.label).tag(m.id)
                }
            } label: {
                Label("Model", systemImage: "cpu")
            }

            // Test connection button
            Button {
                testConnection()
            } label: {
                HStack {
                    Label("Test Connection", systemImage: "antenna.radiowaves.left.and.right")
                    Spacer()
                    testStatusView
                }
            }
            .disabled(!gateway.isConfigured || testStatus == .testing)

        } header: {
            Text("Cloud Gateway")
        } footer: {
            Text("Deploy LiteLLM on AWS EC2 with the config in the /server directory. Supports OpenAI, Gemini, and Anthropic models.")
        }
        .listRowBackground(glassRowBackground)
    }

    @ViewBuilder
    private var testStatusView: some View {
        switch testStatus {
        case .idle:    EmptyView()
        case .testing: ProgressView().controlSize(.small)
        case .success: Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
        case .failure: Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
        }
    }

    // MARK: - About section

    private var aboutSection: some View {
        Section("About") {
            LabeledContent("Version", value: "1.0.0 (Phase 6)")
            LabeledContent("Build",   value: "1")
            LabeledContent("AI",      value: localAvailable ? "On-Device + Cloud" : gateway.isConfigured ? "Cloud Only" : "None")
        }
        .listRowBackground(glassRowBackground)
    }

    // MARK: - Helpers

    private var glassRowBackground: some View {
        RoundedRectangle(cornerRadius: AppTheme.Radius.md)
            .glassEffect(in: RoundedRectangle(cornerRadius: AppTheme.Radius.md))
    }

    private func checkLocalModel() {
        localAvailable = SystemLanguageModel.isReallyAvailable
    }

    private func testConnection() {
        testStatus = .testing
        // Invalidate any cached client so new config is picked up
        appState.ai.invalidateCloudClient()
        Task {
            let client = CloudGatewayClient(
                baseURL: gateway.baseURL,
                apiKey:  gateway.apiKey,
                model:   gateway.model
            )
            let ok = await client.testConnection()
            testStatus = ok ? .success : .failure
            // Reset icon after 3s
            try? await Task.sleep(for: .seconds(3))
            if testStatus != .testing { testStatus = .idle }
        }
    }

    // MARK: - Test status

    enum TestStatus { case idle, testing, success, failure }
}

#Preview {
    SettingsView()
        .environment(AppState())
}
