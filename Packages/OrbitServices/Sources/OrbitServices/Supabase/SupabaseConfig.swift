import Foundation

public enum SupabaseConfig {
    public static let projectURL = URL(string: "https://cdhvlrtocpwrmqjtdvea.supabase.co")!
    public static let anonKey   = "sb_publishable_0_FKf8aDbO4_72JiYb66jw_QqoaAVrK"

    static var restURL:      URL { projectURL.appendingPathComponent("rest/v1") }
    static var authURL:      URL { projectURL.appendingPathComponent("auth/v1") }
    static var realtimeURL:  URL {
        var c = URLComponents(url: projectURL, resolvingAgainstBaseURL: false)!
        c.scheme = "wss"
        c.path   = "/realtime/v1/websocket"
        c.queryItems = [
            .init(name: "apikey", value: anonKey),
            .init(name: "vsn",    value: "1.0.0"),
        ]
        return c.url!
    }
}
