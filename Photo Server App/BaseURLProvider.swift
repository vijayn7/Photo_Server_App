import Foundation

enum ConnectionStatus: Equatable {
    case pinging
    case reachable
    case unreachable
}

enum AuthStatus: Equatable {
    case notLoggedIn
    case loggingIn
    case loggedIn(User)
    case loginFailed(String)
}

struct User: Codable, Equatable {
    let username: String
    let email: String?
    let fullName: String?
    let disabled: Bool?
    let admin: Bool?
    
    enum CodingKeys: String, CodingKey {
        case username, email, disabled, admin
        case fullName = "full_name"
    }
}

struct PhotoMetadata: Codable {
    let width: Int?
    let height: Int?
    let resolution: String?
    let cameraMake: String?
    let cameraModel: String?
    let orientation: Int?
    let dateTaken: String?
    let iso: Int?
    let exposureTime: String?
    let fNumber: String?
    let focalLength: String?
    let hasGps: Bool?
    
    enum CodingKeys: String, CodingKey {
        case width, height, resolution, orientation, iso
        case cameraMake = "camera_make"
        case cameraModel = "camera_model"
        case dateTaken = "date_taken"
        case exposureTime = "exposure_time"
        case fNumber = "f_number"
        case focalLength = "focal_length"
        case hasGps = "has_gps"
    }
}

struct Photo: Codable, Identifiable {
    let id = UUID()
    let filename: String
    let originalName: String
    let uploadedBy: String
    let uploadDate: String
    let uploadTime: String
    let fileSize: Int
    let size: String
    let fileType: String
    let folder: String
    let filePath: String
    let isFavorite: Bool
    let metadata: PhotoMetadata?
    let thumbnailUrl: String?
    let originalUrl: String
    
    enum CodingKeys: String, CodingKey {
        case filename, size, folder, metadata
        case originalName = "original_name"
        case uploadedBy = "uploaded_by"
        case uploadDate = "upload_date"
        case uploadTime = "upload_time"
        case fileSize = "file_size"
        case fileType = "file_type"
        case filePath = "file_path"
        case isFavorite = "is_favorite"
        case thumbnailUrl = "thumbnail_url"
        case originalUrl = "original_url"
    }
}

struct PhotosResponse: Codable {
    let photos: [Photo]
    let total: Int
    let limit: Int
    let offset: Int
    let hasMore: Bool
    
    enum CodingKeys: String, CodingKey {
        case photos, total, limit, offset
        case hasMore = "has_more"
    }
}

struct LoginResponse: Codable {
    let accessToken: String
    let tokenType: String
    
    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case tokenType = "token_type"
    }
}

final class BaseURLProvider: ObservableObject {
    static let shared = BaseURLProvider()

    @Published private(set) var connectionStatus: ConnectionStatus = .pinging
    @Published private(set) var authStatus: AuthStatus = .notLoggedIn
    @Published private(set) var photos: [Photo] = []
    @Published private(set) var isLoadingPhotos = false
    @Published private(set) var isUploading = false
    
    private let serverURL = URL(string: "http://192.168.68.10:8000")!
    private var accessToken: String?
    
    private init() {
        pingServer()
    }

    func pingServer() {
        Task {
            await updateConnectionStatus(.pinging)
            
            let isReachable = await ping()
            
            await updateConnectionStatus(isReachable ? .reachable : .unreachable)
        }
    }
    
    func login(username: String, password: String) {
        Task {
            await updateAuthStatus(.loggingIn)
            
            let success = await performLogin(username: username, password: password)
            
            if !success {
                await updateAuthStatus(.loginFailed("Invalid username or password"))
            }
        }
    }
    
    func logout() {
        Task {
            accessToken = nil
            await updateAuthStatus(.notLoggedIn)
            await clearPhotos()
        }
    }
    
    func loadPhotos(limit: Int = 30, offset: Int = 0) {
        Task {
            await updateLoadingPhotos(true)
            await fetchPhotos(limit: limit, offset: offset)
            await updateLoadingPhotos(false)
        }
    }
    
    func uploadPhoto(imageData: Data, filename: String) {
        Task {
            await updateUploading(true)
            let success = await performUpload(imageData: imageData, filename: filename)
            await updateUploading(false)
            
            if success {
                // Reload photos after successful upload
                await fetchPhotos(limit: 30, offset: 0)
            }
        }
    }
    
    func getPhotoURL(filename: String) -> URL {
        return serverURL.appendingPathComponent("photos").appendingPathComponent(filename)
    }
    
    func getThumbnailURL(filename: String) -> URL {
        return serverURL.appendingPathComponent("thumbnails").appendingPathComponent(filename)
    }
    
    func getAccessToken() -> String? {
        return accessToken
    }
    
    @MainActor
    private func updateConnectionStatus(_ status: ConnectionStatus) {
        self.connectionStatus = status
    }
    
    @MainActor
    private func updateAuthStatus(_ status: AuthStatus) {
        self.authStatus = status
    }
    
    @MainActor
    private func updateLoadingPhotos(_ loading: Bool) {
        self.isLoadingPhotos = loading
    }
    
    @MainActor
    private func updateUploading(_ uploading: Bool) {
        self.isUploading = uploading
    }
    
    @MainActor
    private func updatePhotos(_ newPhotos: [Photo]) {
        self.photos = newPhotos
    }
    
    @MainActor
    private func clearPhotos() {
        self.photos = []
    }

    private func ping() async -> Bool {
        var request = URLRequest(url: serverURL)
        request.httpMethod = "GET"
        request.timeoutInterval = 2.0
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 2.0
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                print("Server responded with status: \(httpResponse.statusCode)")
                return (200...299).contains(httpResponse.statusCode)
            }
            return false
        } catch {
            print("Ping failed: \(error.localizedDescription)")
            return false
        }
    }
    
    private func performLogin(username: String, password: String) async -> Bool {
        let loginURL = serverURL.appendingPathComponent("token")
        
        var request = URLRequest(url: loginURL)
        request.httpMethod = "POST"
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        
        // Form data for OAuth2 password flow
        let formData = "grant_type=password&username=\(username)&password=\(password)"
        request.httpBody = formData.data(using: .utf8)
        
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Login response status: \(httpResponse.statusCode)")
                
                if httpResponse.statusCode == 200 {
                    let loginResponse = try JSONDecoder().decode(LoginResponse.self, from: data)
                    self.accessToken = loginResponse.accessToken
                    
                    // Get user info after successful login
                    await fetchUserInfo()
                    return true
                } else {
                    print("Login failed with status: \(httpResponse.statusCode)")
                    if let errorData = String(data: data, encoding: .utf8) {
                        print("Error response: \(errorData)")
                    }
                }
            }
            return false
        } catch {
            print("Login error: \(error.localizedDescription)")
            return false
        }
    }
    
    private func fetchUserInfo() async {
        guard let token = accessToken else { return }
        
        let userURL = serverURL.appendingPathComponent("users/me")
        var request = URLRequest(url: userURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                let user = try JSONDecoder().decode(User.self, from: data)
                await updateAuthStatus(.loggedIn(user))
                
                // Load photos after successful login
                await fetchPhotos(limit: 30, offset: 0)
            } else {
                await updateAuthStatus(.loginFailed("Failed to get user info"))
            }
        } catch {
            print("Failed to fetch user info: \(error.localizedDescription)")
            await updateAuthStatus(.loginFailed("Failed to get user info"))
        }
    }
    
    private func fetchPhotos(limit: Int, offset: Int) async {
        guard let token = accessToken else { return }
        
        var components = URLComponents(url: serverURL.appendingPathComponent("photos"), resolvingAgainstBaseURL: false)
        components?.queryItems = [
            URLQueryItem(name: "limit", value: String(limit)),
            URLQueryItem(name: "offset", value: String(offset)),
            URLQueryItem(name: "sort_by", value: "date")
        ]
        
        guard let photosURL = components?.url else { return }
        
        var request = URLRequest(url: photosURL)
        request.httpMethod = "GET"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        
        let config = URLSessionConfiguration.ephemeral
        let session = URLSession(configuration: config)
        
        do {
            let (data, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode == 200 {
                // Parse the wrapped response object
                let photosResponse = try JSONDecoder().decode(PhotosResponse.self, from: data)
                await updatePhotos(photosResponse.photos)
                print("Loaded \(photosResponse.photos.count) photos out of \(photosResponse.total) total")
            } else {
                print("Failed to fetch photos: \(response)")
            }
        } catch {
            print("Failed to fetch photos: \(error.localizedDescription)")
        }
    }
    
    private func performUpload(imageData: Data, filename: String) async -> Bool {
        guard let token = accessToken else { return false }
        
        let uploadURL = serverURL.appendingPathComponent("upload")
        
        // Create multipart form data
        let boundary = UUID().uuidString
        var request = URLRequest(url: uploadURL)
        request.httpMethod = "POST"
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        
        var body = Data()
        
        // Add file data
        body.append("--\(boundary)\r\n".data(using: .utf8)!)
        body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
        body.append("Content-Type: image/jpeg\r\n\r\n".data(using: .utf8)!)
        body.append(imageData)
        body.append("\r\n".data(using: .utf8)!)
        body.append("--\(boundary)--\r\n".data(using: .utf8)!)
        
        request.httpBody = body
        
        let config = URLSessionConfiguration.ephemeral
        config.timeoutIntervalForRequest = 60 // Longer timeout for uploads
        let session = URLSession(configuration: config)
        
        do {
            let (_, response) = try await session.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Upload response status: \(httpResponse.statusCode)")
                return httpResponse.statusCode == 200
            }
            return false
        } catch {
            print("Upload error: \(error.localizedDescription)")
            return false
        }
    }
}
