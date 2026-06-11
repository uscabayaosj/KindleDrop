import Foundation
import Network

/// Pure Swift SMTP client using Network framework. No external dependencies.
actor SMTPClient {

    private var connection: NWConnection?
    private let host: String
    private let port: Int
    private let useTLS: Bool
    private let timeout: Double

    private var buffer = ""

    init(host: String, port: Int, useTLS: Bool = true, timeout: Double = 30) {
        self.host = host
        self.port = port
        self.useTLS = useTLS
        self.timeout = timeout
    }

    // MARK: - Public API

    func send(email: String,
                  password: String,
                  from: String,
                  to: String,
                  subject: String,
                  attachmentPath: URL) async throws {
        try await withThrowingTaskGroup(of: Void.self) { group in
            // Real SMTP work
            group.addTask {
                try await self.performSend(
                    email: email, password: password,
                    from: from, to: to,
                    subject: subject, attachmentPath: attachmentPath
                )
            }
            // Timeout task
            group.addTask {
                let seconds = UInt64(self.timeout * 1_000_000_000)
                try await Task.sleep(nanoseconds: seconds)
                throw KindleDropError.smtpError(
                    "Connection timed out after \(Int(self.timeout)) seconds"
                )
            }
            // Wait for whichever finishes first
            try await group.next()
            group.cancelAll()
        }
    }

    /// The actual SMTP send logic, wrapped by send() which enforces a timeout
    private func performSend(email: String,
                  password: String,
                  from: String,
                  to: String,
                  subject: String,
                  attachmentPath: URL) async throws {

            try await connect()
            try await handshake()
            // STARTTLS for ports 587/25 — NOT for 465 (which is direct SMTPS)
            if useTLS && port != 465 {
                try await startTLS()
                try await handshake()
            }
            try await authenticate(username: from, password: password)
            try await sendMail(from: from, to: to, subject: subject, attachmentPath: attachmentPath)
            try await quit()
        }

    /// Quick validation without sending email
    func validate() async throws {
        try await connect()
        try await handshake()
        try await quit()
    }

    // MARK: - Connection

    private func connect() async throws {
        let host = self.host
        let port = self.port
        let timeout = self.timeout

        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = Int(timeout)
        tcpOptions.enableKeepalive = false

        let params: NWParameters
        if port == 465 {
            // Direct SMTPS — TLS from the start
            params = NWParameters(tls: NWProtocolTLS.Options(), tcp: tcpOptions)
        } else {
            // Plain TCP — STARTTLS or unencrypted
            params = NWParameters(tls: nil, tcp: tcpOptions)
        }

        let conn = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port))!,
            using: params
        )

        connection = conn
        conn.start(queue: .global())

        // Wait for connection to be ready
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let guardFlag = GuardFlag()
            conn.stateUpdateHandler = { state in
                guard !guardFlag.isSet else { return }
                switch state {
                case .ready:
                    guardFlag.set()
                    continuation.resume()
                case .failed(let error):
                    guardFlag.set()
                    continuation.resume(throwing: KindleDropError.connectionFailed(error.localizedDescription))
                case .cancelled:
                    guardFlag.set()
                    continuation.resume(throwing: KindleDropError.connectionFailed("Connection cancelled"))
                default:
                    break
                }
            }
        }

        // Read server greeting
        let greeting = try await readLine()
        Swift.print("📨 Server: \(greeting)")
        guard greeting.hasPrefix("220") else {
            throw KindleDropError.smtpError("Server rejected: \(greeting)")
        }
    }

    // MARK: - SMTP Commands

    private func handshake() async throws {
        // EHLO response can be multi-line. Each continuation line starts with "250-".
        // We must consume ALL lines so they don't pollute the buffer for the next command.
        var response = try await sendCommand("EHLO localhost")
        guard response.contains("250") else {
            throw KindleDropError.smtpError("EHLO failed: \(response)")
        }
        // Drain remaining multi-line response
        while response.hasPrefix("250-") {
            response = try await readLine()
        }
    }

    private func startTLS() async throws {
        let response = try await sendCommand("STARTTLS")
        guard response.hasPrefix("220") else {
            throw KindleDropError.smtpError("STARTTLS failed: \(response)")
        }

        // Restart connection with TLS
        let host = self.host
        let port = self.port
        let timeout = self.timeout

        let tlsOptions = NWProtocolTLS.Options()
        let tcpOptions = NWProtocolTCP.Options()
        tcpOptions.connectionTimeout = Int(timeout)

        let params = NWParameters(tls: tlsOptions, tcp: tcpOptions)
        let newConnection = NWConnection(
            host: NWEndpoint.Host(host),
            port: NWEndpoint.Port(rawValue: UInt16(port))!,
            using: params
        )

        connection?.cancel()
        connection = newConnection

        guard let conn = connection else {
            throw KindleDropError.connectionFailed("Failed to create TLS connection")
        }

        conn.start(queue: .global())

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let guardFlag = GuardFlag()
            conn.stateUpdateHandler = { state in
                guard !guardFlag.isSet else { return }
                switch state {
                case .ready:
                    guardFlag.set()
                    continuation.resume()
                case .failed(let error):
                    guardFlag.set()
                    continuation.resume(throwing: KindleDropError.connectionFailed("TLS failed: \(error.localizedDescription)"))
                case .cancelled:
                    guardFlag.set()
                    continuation.resume(throwing: KindleDropError.connectionFailed("TLS connection cancelled"))
                default:
                    break
                }
            }
        }
    }

    private func authenticate(username: String, password: String) async throws {
        let response = try await sendCommand("AUTH LOGIN")
        guard response.hasPrefix("334") else {
            throw KindleDropError.authenticationFailed("AUTH not supported: \(response)")
        }

        let userResp = try await sendCommand(Data(username.utf8).base64EncodedString())
        guard userResp.hasPrefix("334") else {
            throw KindleDropError.authenticationFailed("Username rejected: \(userResp)")
        }

        let passResp = try await sendCommand(Data(password.utf8).base64EncodedString())
        guard passResp.hasPrefix("235") else {
            throw KindleDropError.authenticationFailed("Password rejected: \(passResp)")
        }
    }

    private func sendMail(from: String, to: String, subject: String, attachmentPath: URL) async throws {
        var response = try await sendCommand("MAIL FROM:<\(from)>")
        guard response.hasPrefix("250") else {
            throw KindleDropError.smtpError("MAIL FROM rejected: \(response)")
        }

        response = try await sendCommand("RCPT TO:<\(to)>")
        guard response.hasPrefix("250") else {
            throw KindleDropError.smtpError("RCPT TO rejected: \(response)")
        }

        response = try await sendCommand("DATA")
        guard response.hasPrefix("354") else {
            throw KindleDropError.smtpError("DATA rejected: \(response)")
        }

        let emailData = try buildMimeEmail(from: from, to: to, subject: subject, attachmentPath: attachmentPath)
        try await sendRaw(String(data: emailData, encoding: .utf8) ?? "")

        response = try await sendCommand(".")
        guard response.hasPrefix("250") else {
            throw KindleDropError.smtpError("Message rejected: \(response)")
        }
    }

    private func quit() async throws {
        _ = try? await sendCommand("QUIT")
        connection?.cancel()
        connection = nil
    }

    // MARK: - MIME Email Construction

    private func buildMimeEmail(from: String, to: String, subject: String, attachmentPath: URL) throws -> Data {
        guard FileManager.default.fileExists(atPath: attachmentPath.path) else {
            if attachmentPath.path == "/dev/null" {
                return buildTextEmail(from: from, to: to, subject: subject)
            }
            throw KindleDropError.fileNotFound(attachmentPath.lastPathComponent)
        }

        let fileData = try Data(contentsOf: attachmentPath)
        if fileData.isEmpty {
            throw KindleDropError.smtpError("File is empty: \(attachmentPath.lastPathComponent)")
        }

        let base64Content = fileData.base64EncodedString()
        let fileName = attachmentPath.lastPathComponent
        let boundary = "==KINDLEDROP_BOUNDARY_\(UUID().uuidString.replacingOccurrences(of: "-", with: ""))="

        var message = ""
        message += "From: \(from)\r\n"
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        message += "MIME-Version: 1.0\r\n"
        message += "Content-Type: multipart/mixed; boundary=\"\(boundary)\"\r\n"
        message += "\r\n"
        message += "--\(boundary)\r\n"
        message += "Content-Type: text/plain; charset=\"utf-8\"\r\n"
        message += "\r\n"
        message += "Sent to Kindle via KindleDrop\r\n"
        message += "\r\n"
        message += "--\(boundary)\r\n"
        message += "Content-Type: application/pdf; name=\"\(fileName)\"\r\n"
        message += "Content-Disposition: attachment; filename=\"\(fileName)\"\r\n"
        message += "Content-Transfer-Encoding: base64\r\n"
        message += "\r\n"

        var body = message
        var line = ""
        for char in base64Content {
            line.append(char)
            if line.count == 76 {
                body += line + "\r\n"
                line = ""
            }
        }
        if !line.isEmpty {
            body += line + "\r\n"
        }

        body += "--\(boundary)--\r\n"

        return Data(body.utf8)
    }

    private func buildTextEmail(from: String, to: String, subject: String) -> Data {
        var message = ""
        message += "From: \(from)\r\n"
        message += "To: \(to)\r\n"
        message += "Subject: \(subject)\r\n"
        message += "MIME-Version: 1.0\r\n"
        message += "Content-Type: text/plain; charset=\"utf-8\"\r\n"
        message += "\r\n"
        message += "KindleDrop connection test\r\n"

        return Data(message.utf8)
    }

    // MARK: - Low-level Send/Receive

    private func sendCommand(_ command: String) async throws -> String {
        try await sendRaw(command + "\r\n")
        return try await readLine()
    }

    private nonisolated func sendRaw(_ text: String) async throws {
        let conn = await connection
        guard let conn else {
            throw KindleDropError.connectionFailed("No connection")
        }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            conn.send(content: text.data(using: .utf8),
                      completion: .contentProcessed({ error in
                if let error = error {
                    continuation.resume(throwing: KindleDropError.smtpError("Send failed: \(error.localizedDescription)"))
                } else {
                    continuation.resume()
                }
            }))
        }
    }

    private func readLine() async throws -> String {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<String, Error>) in
            Task { await self.readFromBufferOrNetwork(continuation: continuation) }
        }
    }

    /// Actor-isolated helper for reading — tries buffer first, then reads from network
    private func readFromBufferOrNetwork(continuation: CheckedContinuation<String, Error>) {
        if let newlineRange = buffer.range(of: "\r\n") {
            let line = String(buffer[buffer.startIndex..<newlineRange.lowerBound])
            buffer = String(buffer[newlineRange.upperBound...])
            continuation.resume(returning: line)
            return
        }

        guard let conn = connection else {
            continuation.resume(throwing: KindleDropError.connectionFailed("No connection"))
            return
        }

        conn.receive(minimumIncompleteLength: 1, maximumLength: 65536) { [weak self] content, _, isComplete, error in
            guard let self = self else {
                continuation.resume(throwing: KindleDropError.connectionFailed("Self deallocated"))
                return
            }

            if let error = error {
                continuation.resume(throwing: KindleDropError.smtpError("Read error: \(error.localizedDescription)"))
                return
            }

            if let content = content, let text = String(data: content, encoding: .utf8) {
                Task { await self.appendToBuffer(text, continuation: continuation) }
            } else if isComplete {
                continuation.resume(throwing: KindleDropError.smtpError("Connection closed by server"))
            } else {
                Task { await self.readFromBufferOrNetwork(continuation: continuation) }
            }
        }
    }

    /// Append received data to buffer and try to extract a line
    private func appendToBuffer(_ text: String, continuation: CheckedContinuation<String, Error>) {
        buffer += text
        readFromBufferOrNetwork(continuation: continuation)
    }

    deinit {
        connection?.cancel()
    }
}

/// Thread-safe flag for use in Sendable closures
private final class GuardFlag: @unchecked Sendable {
    private let lock = NSLock()
    private var _isSet = false

    var isSet: Bool {
        lock.withLock { _isSet }
    }

    func set() {
        lock.withLock { _isSet = true }
    }
}