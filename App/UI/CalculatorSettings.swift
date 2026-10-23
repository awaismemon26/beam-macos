import SwiftUI

/// Whether the launcher calculates, and where its currency rates come from.
struct CalculatorSettings: View {
    @Bindable var settings: AppSettings
    let rates: RatesStatus
    @State private var ratesUpdated: Date?
    @State private var refreshing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            SettingsCard {
                SettingsRow("Show calculator results") {
                    Toggle("", isOn: $settings.showCalculator).toggleStyle(.switch).labelsHidden()
                }
                SettingsDivider()
                SettingsRow("Currency Rates") {
                    HStack(spacing: 10) {
                        Text(ratesUpdated.map { "Updated \($0.formatted(.relative(presentation: .named)))" }
                             ?? "Built-in rates")
                            .foregroundStyle(.secondary)
                        Button(refreshing ? "Refreshing…" : "Refresh") {
                            refreshing = true
                            Task {
                                await rates.refresh()
                                ratesUpdated = await rates.lastUpdate()
                                refreshing = false
                            }
                        }
                        .disabled(refreshing)
                    }
                }
            }
        }
        .task { ratesUpdated = await rates.lastUpdate() }
    }
}
