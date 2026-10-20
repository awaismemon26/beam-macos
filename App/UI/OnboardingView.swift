import SwiftUI

/// First-run window shown until Accessibility access is granted.
struct OnboardingView: View {
    @State private var isTrusted = Permissions.isTrusted
    let onGranted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 12) {
                Image(systemName: "command.square.fill")
                    .font(.system(size: 40))
                    .foregroundStyle(.tint)
                Text("Beam needs Accessibility access")
                    .font(.title2.weight(.semibold))
            }
            Text("Beam needs Accessibility access to list your windows and bring the one you pick to the front. Turn on Beam in System Settings → Privacy & Security → Accessibility.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Button("Open System Settings") { Permissions.openAccessibilitySettings() }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.defaultAction)
                Spacer()
                Label(isTrusted ? "Granted" : "Waiting for access…",
                      systemImage: isTrusted ? "checkmark.circle.fill" : "hourglass")
                    .foregroundStyle(isTrusted ? .green : .secondary)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
        .padding(24)
        .frame(width: 460)
        .task {
            await Permissions.waitUntilTrusted()
            withAnimation(Theme.spring) { isTrusted = true }
            try? await Task.sleep(for: .milliseconds(600))
            onGranted()
        }
    }
}
