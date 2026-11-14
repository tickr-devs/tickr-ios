import Foundation
import XCTest
@testable import ApertureKit

/// Answers requests from a canned (status, body) and records what was asked.
final class StubProtocol: URLProtocol {
    static var answer: (Int, Data) = (200, Data())
    static var seen: [URLRequest] = []
    static var seenBodies: [Data] = []

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.seen.append(request)
        Self.seenBodies.append(request.httpBody ?? Self.readStream(request.httpBodyStream))
        let response = HTTPURLResponse(url: request.url!, statusCode: Self.answer.0,
                                       httpVersion: "HTTP/1.1",
                                       headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Self.answer.1)
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}

    static func readStream(_ stream: InputStream?) -> Data {
        guard let stream else { return Data() }
        stream.open()
        defer { stream.close() }
        var data = Data()
        var buffer = [UInt8](repeating: 0, count: 1024)
        while stream.hasBytesAvailable {
            let count = stream.read(&buffer, maxLength: buffer.count)
            if count <= 0 { break }
            data.append(buffer, count: count)
        }
        return data
    }
}

final class APIClientTests: XCTestCase {
    var client: APIClient!

    override func setUp() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [StubProtocol.self]
        client = APIClient(baseURL: URL(string: "http://127.0.0.1:8766")!,
                           session: URLSession(configuration: configuration))
        StubProtocol.seen = []
        StubProtocol.seenBodies = []
    }

    func testStatus() async throws {
        StubProtocol.answer = try (200, fixture("status-response-v1.json"))
        let response = try await client.status()
        XCTAssertEqual(response.status?.environment, "sandbox")
        let request = try XCTUnwrap(StubProtocol.seen.first)
        XCTAssertEqual(request.httpMethod, "GET")
        XCTAssertEqual(request.url?.absoluteString, "http://127.0.0.1:8766/status")
    }

    func testCommandsSendExactBodies() async throws {
        StubProtocol.answer = try (202, fixture("command-accepted-v1.json"))
        let cases: [(OperatorCommand, String, [String: String])] = [
            (.entryStop(on: true), "/commands/entry-stop", ["state": "on"]),
            (.entryStop(on: false), "/commands/entry-stop", ["state": "off"]),
            (.cancelOwnOrders, "/commands/cancel-own-orders", [:]),
            (.flatten, "/commands/flatten", [:]),
        ]
        for (index, (command, path, body)) in cases.enumerated() {
            _ = try await client.send(command)
            let request = StubProtocol.seen[index]
            XCTAssertEqual(request.httpMethod, "POST")
            XCTAssertEqual(request.url?.path, path)
            XCTAssertEqual(request.value(forHTTPHeaderField: "Content-Type"), "application/json")
            XCTAssertNil(request.value(forHTTPHeaderField: "Origin"))
            let sent = try JSONSerialization.jsonObject(with: StubProtocol.seenBodies[index]) as? [String: String]
            XCTAssertEqual(sent, body)
        }
    }

    func testAcceptedWarningIsDecoded() async throws {
        StubProtocol.answer = try (202, fixture("command-accepted-v1.warning.json"))
        let accepted = try await client.send(.flatten)
        XCTAssertEqual(accepted.command.kind, .flatten)
        XCTAssertNotNil(accepted.warning)
    }

    func testTypedRefusal() async throws {
        StubProtocol.answer = try (403, fixture("error-v1.json"))
        do {
            _ = try await client.status()
            XCTFail("expected a refusal")
        } catch let error as APIError {
            guard case .refused(let status, let code, _) = error else { return XCTFail("\(error)") }
            XCTAssertEqual(status, 403)
            XCTAssertEqual(code, "forbidden_host")
        }
    }

    func testNonContractAnswerIsAContractError() async throws {
        StubProtocol.answer = (200, Data("{\"api_version\": 2}".utf8))
        do {
            _ = try await client.status()
            XCTFail("expected a contract error")
        } catch let error as APIError {
            guard case .contract = error else { return XCTFail("\(error)") }
        }
        StubProtocol.answer = (500, Data("oops".utf8))
        do {
            _ = try await client.status()
            XCTFail("expected a contract error")
        } catch let error as APIError {
            guard case .contract = error else { return XCTFail("\(error)") }
        }
    }

    func testPendingCommands() async throws {
        StubProtocol.answer = try (200, fixture("pending-commands-v1.json"))
        let pending = try await client.pendingCommands()
        XCTAssertEqual(pending.commands.map(\.kind), [.flatten])
    }
}
