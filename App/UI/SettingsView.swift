import BeamCalc
import SwiftUI

struct SettingsView: View {
    @Bindable var settings: AppSettings
    let calculator: CalculatorService

    @State private var launchAtLogin = LoginItem.isEnabled
    @State private var loginError: String?
    @State private var isTrusted = Permissions.isTrusted
    @State private var ratesUpdated: Date?
    @State private var refreshing = false

    var body: some View {
        Form {
            Section("General") {
                Toggle("Launch Beam at login", isOn: $launchAtLogin)
                    .onChange(of: launchAtLogin) { _, on in
                        do { try LoginItem.set(on); loginError = nil } catch {
                            loginError = error.localizedDescription
                            launchAtLogin = LoginItem.isEnabled
                        }
                    }
                if let loginError {
                    Text(loginError).font(.caption).foregroundStyle(.red)
                }
                LabeledContent("Open Beam") { HotkeyRecorder(settings: settings) }
            }
            Section("Shortcuts") {
                LabeledContent("Switch windows of current app", value: "⌃⇥")
                LabeledContent("Search all windows", value: "⌥⇥")
            }
            Section("Permissions") {
                LabeledContent("Accessibility") {
                    if isTrusted {
                        Label("Granted", systemImage: "checkmark.circle.fill").foregroundStyle(.green)
                    } else {
                        HStack {
                            Label("Not granted", systemImage: "exclamationmark.triangle.fill").foregroundStyle(.orange)
                            Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                        }
                    }
                }
            }
            Section("Calculator") {
                LabeledContent("Currency rates") {
                    HStack {
                        if let ratesUpdated {
                            Text("Updated \(ratesUpdated, format: .relative(presentation: .named))")
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Using built-in rates").foregroundStyle(.secondary)
                        }
                        Button(refreshing ? "Refreshing…" : "Refresh now") {
                            refreshing = true
                            Task {
                                await calculator.refreshRates()
                                ratesUpdated = await calculator.lastRatesUpdate
                                refreshing = false
                            }
                        }
                        .disabled(refreshing)
                    }
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 480)
        .fixedSize(horizontal: false, vertical: true)
        .task {
            ratesUpdated = await calculator.lastRatesUpdate
            while !Task.isCancelled {
                isTrusted = Permissions.isTrusted
                launchAtLogin = LoginItem.isEnabled
                try? await Task.sleep(for: .seconds(3))
            }
        }
    }
}
