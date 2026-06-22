import Foundation

// MARK: - Token Storage

private enum Keychain {
    static let accessKey  = "orbit.supabase.access_token"
    static let refreshKey = "orbit.supabase.refresh_token"
    static let userIdKey  = "orbit.supabase.user_id"

    static func save(_ value: String, forKey key: String) {
        let data = Data(value.utf8)
        let query: [CFString: Any] = [
            kSecClass:            kSecClassGenericPassword,
            kSecAttrAccount:      key,
            kSecValueData:        data,
            kSecAttrAccessible:   kSecAttrAccessibleAfterFirstUnlock,
        ]
        SecItemDelete(query as CFDictionary)
        SecItemAdd(query as CFDictionary, nil)
    }

    static func load(forKey key: String) -> String? {
        let query: [CFString: Any] = [
            kSecClass:       kSecClassGenericPassword,
            kSecAttrAccount: key,
            kSecReturnData:  true,
            kSecMatchLimit:  kSecMatchLimitOne,
        ]
        var result: AnyObject?
        guard SecItemCopyMatching(query as CFDictionary, &result) == errSecSuccess,
              let data = result as? Data else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func delete(forKey key: String) {
        let query: [CFString: Any] = [kSecClass: kSecClassGenericPassword, kSecAttrAccount: key]
        SecItemDelete(query as CFDictionary)
    }
}

// MARK: - HTTP Client

public final class SupabaseClient: @unchecked Sendable {

    public static let shared = SupabaseClient()

    private(set) var accessToken:  String? { didSet { if let t = accessToken  { Keychain.save(t, forKey: Keychain.accessKey)  } else { Keychain.delete(forKey: Keychain.accessKey)  } } }
    private(set) var refreshToken: String? { didSet { if let t = refreshToken { Keychain.save(t, forKey: Keychain.refreshKey) } else { Keychain.delete(forKey: Keychain.refreshKey) } } }
    private(set) var userId:       String? { didSet { if let t = userId       { Keychain.save(t, forKey: Keychain.userIdKey)  } else { Keychain.delete(forKey: Keychain.userIdKey)  } } }

    private init() {
        accessToken  = Keychain.load(forKey: Keychain.accessKey)
        refreshToken = Keychain.load(forKey: Keychain.refreshKey)
        userId       = Keychain.load(forKey: Keychain.userIdKey)
    }

    var isSignedIn: Bool { accessToken != nil && userId != nil }

    func setSession(access: String, refresh: String, userId: String) {
        self.accessToken  = access
        self.refreshToken = refresh
        self.userId       = userId
    }

    func clearSession() {
        accessToken = nil; refreshToken = nil; userId = nil
        Keychain.delete(forKey: Keychain.accessKey)
        Keychain.delete(forKey: Keychain.refreshKey)
        Keychain.delete(forKey: Keychain.userIdKey)
    }

    // MARK: - Auth Requests

    func sendOTP(phone: String) async throws {
        let body: [String: Any] = ["phone": e164(phone), "channel": "sms"]
        try await authRequest("otp", method: "POST", body: body, requiresAuth: false)
    }

    func verifyOTP(phone: String, code: String) async throws -> (access: String, refresh: String, userId: String) {
        let body: [String: Any] = ["phone": e164(phone), "token": code, "type": "sms"]
        let json = try await authRequestJSON("verify", method: "POST", body: body, requiresAuth: false)
        guard
            let access  = json["access_token"]  as? String,
            let refresh = json["refresh_token"] as? String,
            let user    = json["user"] as? [String: Any],
            let uid     = user["id"] as? String
        else { throw SupabaseError.authFailed("验证码错误或已过期") }
        return (access, refresh, uid)
    }

    func refreshSession() async throws {
        guard let rt = refreshToken else { throw SupabaseError.notAuthenticated }
        let body: [String: Any] = ["refresh_token": rt]
        let json = try await authRequestJSON("token?grant_type=refresh_token", method: "POST", body: body, requiresAuth: false)
        guard
            let access  = json["access_token"]  as? String,
            let refresh = json["refresh_token"] as? String,
            let user    = json["user"] as? [String: Any],
            let uid     = user["id"] as? String
        else { throw SupabaseError.authFailed("会话刷新失败") }
        setSession(access: access, refresh: refresh, userId: uid)
    }

    // MARK: - REST Requests

    func get(_ table: String, query: [String: String] = [:]) async throws -> [[String: Any]] {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        let url = components.url!
        let data = try await request(url: url, method: "GET")
        return try JSONSerialization.jsonObject(with: data) as? [[String: Any]] ?? []
    }

    func post(_ table: String, body: [String: Any]) async throws -> [String: Any] {
        let url = SupabaseConfig.restURL.appendingPathComponent(table)
        let data = try await request(url: url, method: "POST", body: body,
                                     extra: ["Prefer": "return=representation"])
        let arr = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        return arr?.first ?? [:]
    }

    func patch(_ table: String, query: [String: String], body: [String: Any]) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        _ = try await request(url: components.url!, method: "PATCH", body: body)
    }

    func upsert(_ table: String, body: [String: Any]) async throws {
        let url = SupabaseConfig.restURL.appendingPathComponent(table)
        _ = try await request(url: url, method: "POST", body: body,
                              extra: ["Prefer": "resolution=merge-duplicates"])
    }

    func delete(_ table: String, query: [String: String]) async throws {
        var components = URLComponents(url: SupabaseConfig.restURL.appendingPathComponent(table), resolvingAgainstBaseURL: false)!
        components.queryItems = query.map { URLQueryItem(name: $0.key, value: $0.value) }
        _ = try await request(url: components.url!, method: "DELETE")
    }

    func rpc(_ fn: String, body: [String: Any]) async throws -> Data {
        let url = SupabaseConfig.restURL.appendingPathComponent("rpc/\(fn)")
        return try await request(url: url, method: "POST", body: body)
    }

    // MARK: - Core HTTP

    private func request(url: URL, method: String, body: [String: Any]? = nil,
                         extra: [String: String] = [:]) async throws -> Data {
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.setValue("application/json", forHTTPHeaderField: "Accept")
        if let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        for (k, v) in extra { req.setValue(v, forHTTPHeaderField: k) }
        if let body { req.httpBody = try JSONSerialization.data(withJSONObject: body) }

        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0

        if status == 401 {
            try await refreshSession()
            return try await request(url: url, method: method, body: body, extra: extra)
        }
        guard (200..<300).contains(status) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            throw SupabaseError.network(msg)
        }
        return data
    }

    // MARK: - Auth HTTP helpers

    @discardableResult
    private func authRequest(_ path: String, method: String, body: [String: Any],
                             requiresAuth: Bool) async throws -> Data {
        let url = SupabaseConfig.authURL.appendingPathComponent(path)
        var req = URLRequest(url: url)
        req.httpMethod = method
        req.setValue(SupabaseConfig.anonKey, forHTTPHeaderField: "apikey")
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if requiresAuth, let token = accessToken {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        }
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        let (data, response) = try await URLSession.shared.data(for: req)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard (200..<300).contains(status) else {
            let msg = (try? JSONSerialization.jsonObject(with: data) as? [String: Any])?["message"] as? String ?? "HTTP \(status)"
            throw SupabaseError.authFailed(msg)
        }
        return data
    }

    private func authRequestJSON(_ path: String, method: String, body: [String: Any],
                                 requiresAuth: Bool) async throws -> [String: Any] {
        let data = try await authRequest(path, method: method, body: body, requiresAuth: requiresAuth)
        return (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
    }

    // MARK: - Phone formatting

    private func e164(_ phone: String) -> String {
        let digits = phone.filter(\.isNumber)
        if digits.hasPrefix("86") && digits.count == 13 { return "+\(digits)" }
        if digits.count == 11 && digits.hasPrefix("1") { return "+86\(digits)" }
        return "+\(digits)"
    }
}

// MARK: - Error

public enum SupabaseError: LocalizedError {
    case notAuthenticated
    case authFailed(String)
    case network(String)
    case decoding(String)

    public var errorDescription: String? {
        switch self {
        case .notAuthenticated:   return "请先登录"
        case .authFailed(let m):  return "认证失败：\(m)"
        case .network(let m):     return "网络错误：\(m)"
        case .decoding(let m):    return "数据解析失败：\(m)"
        }
    }
}
