import ApertureKit
import Foundation
import SwiftUI

/// Polls GET /status and sends operator commands. Shared by the macOS app and a later iOS app.
@MainActor
public final class StatusModel: ObservableObject {
    @Published public private(set) var response: StatusResponseV1?
    @Published public private(set) var fetchError: String?
    @Published public private(set) var lastCommandMessage: String?
    @Published public private(set) var sending = false

    public let client: APIClient
    private var pollTask: Task<Void, Never>?
    /// Used only until the first answer tells us the server's poll_seconds.
    private let initialPollSeconds: Double = 3

    public init(client: APIClient) {
        self.client = client
    }

    public var headline: Headline { Headline.make(response: response, fetchError: fetchError) }

    public func start() {
        guard pollTask == nil else { return }
        pollTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.refresh()
                let seconds = self.response.map { NSDecimalNumber(decimal: $0.pollSeconds.value).doubleValue }
                    ?? self.initialPollSeconds
                try? await Task.sleep(nanoseconds: UInt64(max(seconds, 1) * 1_000_000_000))
            }
        }
    }

    public func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    public func refresh() async {
        do {
            response = try await client.status()
            fetchError = nil
        } catch {
            fetchError = (error as? LocalizedError)?.errorDescription ?? String(describing: error)
        }
    }

    public func send(_ command: OperatorCommand) async {
        sending = true
        defer { sending = false }
        do {
            let accepted = try await client.send(command)
            var message = "\(Display.commandTitle(command.kind)) queued for the bot "
                + "(id \(accepted.command.commandId.prefix(8))). The result appears under Recent commands."
            if let warning = accepted.warning { message += " Warning: \(warning)." }
            lastCommandMessage = message
        } catch {
            lastCommandMessage = "\(Display.commandTitle(command.kind)) not sent: "
                + ((error as? LocalizedError)?.errorDescription ?? String(describing: error))
        }
        await refresh()
    }
}

public extension Severity {
    var color: Color {
        switch self {
        case .ok: return .green
        case .attention: return .orange
        case .alarm: return .red
        }
    }

    var symbolName: String {
        switch self {
        case .ok: return "checkmark.circle.fill"
        case .attention: return "pause.circle.fill"
        case .alarm: return "exclamationmark.triangle.fill"
        }
    }
}
