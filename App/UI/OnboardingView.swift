import AppKit
import SwiftUI

/// First-run window shown until Accessibility access is granted.
struct OnboardingView: View {
    /// After this long without access, explain the "already on but not working" case.
    private static let staleHintDelay: Duration = .seconds(6)

    @State private var isTrusted = Permissions.isTrusted
    @State private var showsStaleHint = false
    @State private var resetFailed = false
    @State private var isResetting = false
    let onGranted: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(spacing: 14) {
                Image(nsImage: NSApp.applicationIconImage)
                    .resizable()
                    .frame(width: 56, height: 56)
                Text("Beam needs Accessibility access")
                    .font(.title2.weight(.semibold))
            }
            Text("Beam needs Accessibility access to list your windows and bring the one you pick to the front. Turn on Beam in System Settings → Privacy & Security → Accessibility (called “Device Control and Data Access” on recent macOS).")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if showsStaleHint && !isTrusted {
                staleHint.transition(.opacity.combined(with: .move(edge: .top)))
            }
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
        .frame(width: 480)
        .task {
            try? await Task.sleep(for: Self.staleHintDelay)
            withAnimation(Theme.spring) { showsStaleHint = true }
        }
        .task {
            await Permissions.waitUntilTrusted()
            withAnimation(Theme.spring) { isTrusted = true }
            try? await Task.sleep(for: .milliseconds(600))
            onGranted()
        }
    }

    private var staleHint: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("Beam is already switched on?", systemImage: "exclamationmark.triangle.fill")
                .font(.headline)
                .foregroundStyle(.orange)
            Text(resetFailed
                 ? "macOS didn't allow the reset. In System Settings, select Beam, remove it with –, then click Open System Settings again and switch the new entry on."
                 : "That entry belongs to an older copy of Beam, so macOS ignores it. Reset it, then switch Beam on again.")
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(isResetting ? "Resetting…" : "Reset permission") {
                isResetting = true
                Task {
                    let ok = await Permissions.resetAndPrompt()
                    withAnimation(Theme.spring) { resetFailed = !ok }
                    isResetting = false
                }
            }
            .disabled(isResetting)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color.orange.opacity(0.08)))
    }
}
