import Foundation

enum Endpoints {
    static let local = URL(string: "https://192.168.68.10:8000")!
    static let localHTTP = URL(string: "http://192.168.68.10:8000")!
    static let probePath = "/"
    
    static func isLocal(_ url: URL) -> Bool {
        return url.host == local.host
    }
    
    static func httpVersion(of url: URL) -> URL? {
        if url.scheme == "https" {
            return URL(string: url.absoluteString.replacingOccurrences(of: "https://", with: "http://"))
        }
        return url
    }
}
