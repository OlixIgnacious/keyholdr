import SwiftUI

struct OnboardingView: View {
    let onDismiss: () -> Void
    var ctaTitle: String = "Add your first key"
    var ctaShortcut: String? = "⌘N"

    var body: some View {
        ZStack {
            KHTheme.paper.ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()

                // Logo mark
                Image(systemName: "key.fill")
                    .font(.system(size: 26, weight: .light))
                    .foregroundColor(KHTheme.ink)
                    .padding(.bottom, 10)

                Text("Keyholdr")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundColor(KHTheme.ink)

                Text("Your keys, one keystroke away.")
                    .font(.system(size: 12))
                    .foregroundColor(KHTheme.ink40)
                    .padding(.top, 3)
                    .padding(.bottom, 18)

                // Three key facts
                VStack(spacing: 0) {
                    OnboardingRow(
                        icon: "keyboard",
                        title: "Global shortcut",
                        detail: "Press ⌃⌥⌘K from anywhere to summon or dismiss Keyholdr."
                    )
                    Divider().background(KHTheme.ink06)
                    OnboardingRow(
                        icon: "touchid",
                        title: "Touch ID on every copy",
                        detail: "The first copy shows a macOS Keychain permission — choose Always Allow and it won't ask again."
                    )
                    Divider().background(KHTheme.ink06)
                    OnboardingRow(
                        icon: "lock.shield",
                        title: "Strictly local",
                        detail: "No servers, no sync, no analytics. Your keys never leave your Keychain."
                    )
                    Divider().background(KHTheme.ink06)
                    OnboardingRow(
                        icon: "power",
                        title: "Off at login by default",
                        detail: "Flip the AUTOSTART toggle in the footer if you want Keyholdr to survive reboots."
                    )
                }
                .background(KHTheme.field)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .strokeBorder(KHTheme.ink12, lineWidth: 1)
                )
                .padding(.horizontal, 20)

                Spacer()

                // CTA
                Button(action: onDismiss) {
                    HStack(spacing: 6) {
                        Text(ctaTitle)
                            .font(.system(size: 13, weight: .medium))
                        if let ctaShortcut {
                            Text(ctaShortcut)
                                .font(.system(size: 11, weight: .medium, design: .monospaced))
                                .opacity(0.6)
                        }
                    }
                    .foregroundColor(KHTheme.paper)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(KHTheme.ink)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(.plain)
                .padding(.horizontal, 20)
                .padding(.bottom, 16)
            }
        }
    }
}

private struct OnboardingRow: View {
    let icon: String
    let title: String
    let detail: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .light))
                .foregroundColor(KHTheme.ink60)
                .frame(width: 20)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(KHTheme.ink)
                Text(detail)
                    .font(.system(size: 11))
                    .foregroundColor(KHTheme.ink40)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 9)
    }
}
