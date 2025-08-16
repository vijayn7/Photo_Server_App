import Foundation
import Network

final class BaseURLProvider: ObservableObject {
    static let shared = BaseURLProvider()

    @Published private(set) var baseURL: URL = Endpoints.publicWAN
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "net.monitor")
    private var lastCheck = Date.distantPast
    private let recheckInterval: TimeInterval = 60

    private init() {
        monitor.pathUpdateHandler = { [weak self] _ in
            Task { await self?.refreshIfStale(force: true) }
        }
        monitor.start(queue: queue)
        Task { await refreshIfStale(force: true) }
    }

    func url() async -> URL {
        await refreshIfStale()
        return baseURL
    }

    @discardableResult
    func refreshIfStale(force: Bool = false) async -> URL {
        if !force, Date().timeIntervalSince(lastCheck) < recheckInterval { return baseURL }
        lastCheck = Date()

        if await isReachable(Endpoints.local, path: Endpoints.probePath, timeout: 0.75) {
            updateBase(Endpoints.local)
            return baseURL
        }
        if await isReachable(Endpoints.publicWAN, path: Endpoints.probePath, timeout: 2.0) {
            updateBase(Endpoints.publicWAN)
            return baseURL
        }
        return baseURL
    }

    private func updateBase(_ url: URL) {
        if baseURL != url {
            DispatchQueue.main.async { [weak self] in self?.baseURL = url }
        }
    }

    private func isReachable(_ host: URL, path: String, timeout: TimeInterval) async -> Bool {
        var req = URLRequest(url: host.appending(path: path))
        req.httpMethod = "GET"
        req.cachePolicy = .reloadIgnoringLocalCacheData
        req.timeoutInterval = timeout

        let cfg = URLSessionConfiguration.ephemeral
        cfg.waitsForConnectivity = false
        let session = URLSession(configuration: cfg)

        do {
            let (_, resp) = try await session.data(for: req)
            if let http = resp as? HTTPURLResponse { return (200..<400).contains(http.statusCode) }
            return false
        } catch {
            return false
        }
    }
}
