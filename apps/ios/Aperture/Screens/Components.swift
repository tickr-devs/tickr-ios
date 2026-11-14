import ApertureDesign
import ApertureKit
import SwiftUI

extension Severity {
    var tint: Color {
        switch self {
        case .ok: return Palette.tealStrong
        case .attention: return Palette.amberStrong
        case .alarm: return Palette.redStrong
        }
    }
}

extension Board.Event.Tone {
    var ticker: TickerItem.Tone {
        switch self {
        case .teal: return .teal
        case .green: return .green
        case .blue: return .blue
        case .amber: return .amber
        case .violet: return .violet
        case .red: return .red
        case .muted: return .muted
        }
    }

    var color: Color {
        switch self {
        case .teal: return Palette.teal
        case .green: return Palette.green
        case .blue: return Palette.blue
        case .amber: return Palette.amber
        case .violet: return Palette.violet
        case .red: return Palette.red
        case .muted: return Palette.dim
        }
    }
}

extension StopState {
    var isProtected: Bool { self == .verified }
}

extension DecimalString {
    var signedMoney: String { Money.signed(value) }
}

/// Money and time formatting used across screens.
enum Format {
    static func time(_ date: Date) -> String {
        date.formatted(date: .omitted, time: .shortened)
    }

    static func clock(_ date: Date) -> String {
        date.formatted(.dateTime.hour(.twoDigits(amPM: .omitted)).minute(.twoDigits).second(.twoDigits))
    }

    /// "updated 3 s ago" from the API's age of the status document.
    static func age(_ response: StatusResponseV1?) -> String {
        guard let response, let age = response.ageSeconds else { return "no status yet" }
        let seconds = NSDecimalNumber(decimal: age.value).intValue
        return response.stale ? "stale · written \(seconds) s ago" : "updated \(seconds) s ago"
    }
}

/// Every tab draws on the same background and keeps its own navigation stack.
struct Screen<Content: View>: View {
    let title: String
    let content: Content

    init(_ title: String, @ViewBuilder content: () -> Content) {
        self.title = title
        self.content = content()
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) { content }
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
        }
        .scrollContentBackground(.hidden)
        .background(ApertureBackground())
        .navigationTitle(title)
    }
}

/// Shown instead of data when the phone has no address for the bot or cannot reach it.
struct ConnectionPrompt: View {
    @Environment(AppModel.self) private var model

    var body: some View {
        if !model.isConfigured {
            ContentUnavailableView {
                Label("Connect to your Mac", systemImage: "desktopcomputer.and.arrow.down")
            } description: {
                Text("Enter the address of the bot's API in Settings.")
            } actions: {
                NavigationLink("Open Settings") { SettingsView() }
                    .buttonStyle(.borderedProminent)
            }
            .rise()
        } else if model.status == nil, let cause = model.fetchError ?? model.response?.unavailableCause {
            ContentUnavailableView {
                Label("No status from the bot", systemImage: "antenna.radiowaves.left.and.right.slash")
            } description: {
                Text(cause)
            }
            .rise()
        }
    }
}

/// A label and a value in a small card, used in rows of three.
struct StatTile: View {
    let label: String
    let value: String
    var color: Color = Palette.text

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            CardLabel(label)
            Text(value)
                .font(.system(size: 15, weight: .bold, design: .monospaced))
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 11)
        .padding(.vertical, 9)
        .apertureCard(radius: 14)
        .accessibilityElement(children: .combine)
    }
}

/// The environment badge (SANDBOX / PRODUCTION) from the status document.
struct EnvironmentBadge: View {
    let environment: String

    var body: some View {
        Text(environment.uppercased())
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .foregroundStyle(Palette.amberStrong)
            .background(Palette.amber.opacity(0.12), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay(RoundedRectangle(cornerRadius: 8, style: .continuous).strokeBorder(Palette.amber.opacity(0.4)))
            .accessibilityLabel("Environment \(environment)")
    }
}

/// The command notice floating at the top of the screen, with haptics, gone after a few seconds.
struct NoticeOverlay: ViewModifier {
    @Environment(AppModel.self) private var model

    func body(content: Content) -> some View {
        content
            .overlay(alignment: .top) {
                if let notice = model.notice {
                    Text(notice.text)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color(notice.tone))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.regularMaterial, in: Capsule())
                        .shadow(color: .black.opacity(0.18), radius: 16, y: 8)
                        .padding(.horizontal, 24)
                        .padding(.top, 8)
                        .transition(.move(edge: .top).combined(with: .opacity))
                        .id(notice.id)
                        .task(id: notice.id) {
                            try? await Task.sleep(for: .seconds(4))
                            if model.notice?.id == notice.id { model.notice = nil }
                        }
                        .onTapGesture { model.notice = nil }
                }
            }
            .animation(.spring(response: 0.45, dampingFraction: 0.8), value: model.notice)
            .sensoryFeedback(trigger: model.notice) { _, new in
                switch new?.tone {
                case .success: return .success
                case .failure: return .error
                case .info: return .impact(weight: .light)
                case nil: return nil
                }
            }
    }

    private func color(_ tone: Notice.Tone) -> Color {
        switch tone {
        case .info: return Palette.blueStrong
        case .success: return Palette.greenStrong
        case .failure: return Palette.redStrong
        }
    }
}

extension Format {
    static func timeOrDash(_ time: WireTime?) -> String {
        time.map { clock($0.date) } ?? "—"
    }
}
