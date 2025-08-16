import Foundation

enum AppConfig {
    static let pageLimit = 60
    
    // Network configuration
    static let localServerTimeout: TimeInterval = 1.0
    static let remoteServerTimeout: TimeInterval = 4.0
    static let normalRetryInterval: TimeInterval = 60
    static let offlineRetryInterval: TimeInterval = 300 // 5 minutes when offline
    static let maxRetryAttempts = 3
    
    // SSL configuration
    static let allowInsecureLocalConnections = true
    static let fallbackToHTTP = true
}
