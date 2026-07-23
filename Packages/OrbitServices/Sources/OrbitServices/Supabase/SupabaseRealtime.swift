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
    private var reconnectScheduled = false

    // table → continuations
    private var listeners: [String: [UUID: (SupabaseChange) -> Void]] = [:]
    // subscription id → (table, filter), kept so we can re-join channels on (re)connect
    private var subscriptions: [UUID: (table: String, filter: String?)] = [:]

    private override init() { super.init() }

    // MARK: - Connect

    func connect() {
        guard !isConnected else { return }
        socket?.cancel()
        let session = URLSession(configuration: .default, delegate: self, delegateQueue: .main)
        self.session = session
        socket = session.webSocketTask(with: SupabaseConfig.realtimeURL)
        socket?.resume()
        isConnected = true
        receiveLoop()
        startHeartbeat()
    }

    func disconnect() {
        heartbeatTask?.cancel(); heartbeatTask = nil
        socket?.cancel()
        socket = nil
        isConnected = false
        reconnectScheduled = false
    }

    // MARK: - Subscribe

    @discardableResult
    func subscribe(table: String, filter: String? = nil,
                   onChange: @escaping (SupabaseChange) -> Void) -> UUID {
        let id = UUID()
        // NOTE: dictionaries are value types — mutated copy would be discarded,
        // so assign back explicitly.
        var tableListeners = listeners[table] ?? [:]
        tableListeners[id] = onChange
        listeners[table] = tableListeners
        subscriptions[id] = (table: table, filter: filter)

        if isConnected {
            joinChannel(table: table, filter: filter)
        } else {
            connect()
        }
        return id
    }

    func unsubscribe(table: String, id: UUID) {
        if subscriptions.removeValue(forKey: id) != nil {
            var tableListeners = listeners[table] ?? [:]
            tableListeners.removeValue(forKey: id)
            listeners[table] = tableListeners
        }
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
                self.reconnect()
            }
        }
    }

    private func reconnect() {
        guard !reconnectScheduled else { return }
        reconnectScheduled = true
        Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            reconnectScheduled = false
            connect()
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
            // Re-join every previously subscribed channel after a (re)connection,
            // otherwise realtime updates silently stop delivering.
            for sub in self.subscriptions.values {
                self.joinChannel(table: sub.table, filter: sub.filter)
            }
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
