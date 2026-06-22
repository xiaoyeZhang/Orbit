import Foundation

// MARK: - Supabase Realtime (Phoenix Channels over WebSocket)

@MainActor
public final class SupabaseRealtime: NSObject {

    public static let shared = SupabaseRealtime()

    private var socket: URLSessionWebSocketTask?
    private var session: URLSession?
    private var ref = 0
    private var heartbeatTask: Task<Void, Never>?
    private var isConnected = false

    // table → continuations
    private var listeners: [String: [UUID: (SupabaseChange) -> Void]] = [:]

    private override init() { super.init() }

    // MARK: - Connect

    func connect() {
        guard !isConnected else { return }
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        socket = session.webSocketTask(with: SupabaseConfig.realtimeURL)
        socket?.resume()
        isConnected = true
        receiveLoop()
        startHeartbeat()
    }

    func disconnect() {
        heartbeatTask?.cancel()
        socket?.cancel()
        socket = nil
        isConnected = false
    }

    // MARK: - Subscribe

    @discardableResult
    func subscribe(table: String, filter: String? = nil,
                   onChange: @escaping (SupabaseChange) -> Void) -> UUID {
        let id = UUID()
        listeners[table, default: [:]][id] = onChange
        joinChannel(table: table, filter: filter)
        return id
    }

    func unsubscribe(table: String, id: UUID) {
        listeners[table]?[id] = nil
    }

    // MARK: - Private

    private func joinChannel(table: String, filter: String?) {
        var config: [String: Any] = [
            "broadcast": ["ack": false, "self": false],
            "presence":  ["key": ""],
            "postgres_changes": [[
                "event":  "*",
                "schema": "public",
                "table":  table,
            ] as [String: Any]],
        ]
        if let f = filter {
            if var arr = (config["postgres_changes"] as? [[String: Any]]),
               var first = arr.first {
                first["filter"] = f
                arr[0] = first
                config["postgres_changes"] = arr
            }
        }
        send(event: "phx_join",
             topic: "realtime:public:\(table)",
             payload: ["config": config])
    }

    private func send(event: String, topic: String, payload: [String: Any]) {
        ref += 1
        let msg: [String: Any] = ["event": event, "topic": topic,
                                  "payload": payload, "ref": String(ref)]
        guard let data = try? JSONSerialization.data(withJSONObject: msg),
              let str  = String(data: data, encoding: .utf8) else { return }
        socket?.send(.string(str)) { _ in }
    }

    private func receiveLoop() {
        socket?.receive { [weak self] result in
            guard let self else { return }
            switch result {
            case .success(let msg):
                if case .string(let str) = msg { self.handleMessage(str) }
                self.receiveLoop()
            case .failure:
                self.isConnected = false
                Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 3_000_000_000)
                    self.connect()
                }
            }
        }
    }

    private func handleMessage(_ str: String) {
        guard
            let data    = str.data(using: .utf8),
            let json    = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let event   = json["event"] as? String,
            event == "postgres_changes",
            let payload = json["payload"] as? [String: Any],
            let data2   = payload["data"] as? [String: Any],
            let table   = data2["table"] as? String
        else { return }

        let change = SupabaseChange(
            eventType: data2["type"] as? String ?? "",
            table:     table,
            record:    data2["record"] as? [String: Any] ?? [:],
            old:       data2["old_record"] as? [String: Any]
        )
        listeners[table]?.values.forEach { $0(change) }
    }

    private func startHeartbeat() {
        heartbeatTask?.cancel()
        heartbeatTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 25_000_000_000)
                self?.send(event: "heartbeat", topic: "phoenix", payload: [:])
            }
        }
    }
}

extension SupabaseRealtime: URLSessionWebSocketDelegate {
    public nonisolated func urlSession(_ session: URLSession,
                            webSocketTask: URLSessionWebSocketTask,
                            didOpenWithProtocol protocol: String?) {
        Task { @MainActor in
            // Re-join all channels on reconnect
        }
    }
}

// MARK: - Change Model

public struct SupabaseChange {
    public let eventType: String  // INSERT / UPDATE / DELETE
    public let table:     String
    public let record:    [String: Any]
    public let old:       [String: Any]?
}
