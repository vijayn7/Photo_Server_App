import SwiftUI
import PhotosUI
import Foundation

@main
struct PhotoServerApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
    }
}

struct ContentView: View {
    @StateObject private var baseURLProvider = BaseURLProvider.shared
    
    var body: some View {
        NavigationView {
            switch baseURLProvider.authStatus {
            case .loggedIn(let user):
                PhotoGalleryView(user: user)
            default:
                LoginFlowView()
            }
        }
    }
}

struct LoginFlowView: View {
    @StateObject private var baseURLProvider = BaseURLProvider.shared
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Photo Server")
                .font(.title)
                .fontWeight(.bold)
            
            // Connection Status
            connectionStatusView
            
            // Authentication Section
            if case .reachable = baseURLProvider.connectionStatus {
                authenticationView
            }
        }
        .padding()
    }
    
    @ViewBuilder
    private var connectionStatusView: some View {
        VStack(spacing: 12) {
            Text("Server Status")
                .font(.headline)
            
            HStack {
                connectionIcon
                VStack(alignment: .leading, spacing: 4) {
                    Text(connectionStatusText)
                        .fontWeight(.medium)
                    Text("192.168.68.10:8000")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(connectionBackgroundColor)
            .cornerRadius(12)
            
            Button("Test Connection") {
                baseURLProvider.pingServer()
            }
            .buttonStyle(.bordered)
        }
    }
    
    @ViewBuilder
    private var authenticationView: some View {
        VStack(spacing: 12) {
            Text("Authentication")
                .font(.headline)
            
            switch baseURLProvider.authStatus {
            case .notLoggedIn:
                LoginView()
            case .loggingIn:
                VStack {
                    ProgressView()
                        .scaleEffect(0.8)
                    Text("Logging in...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
            case .loginFailed(let error):
                VStack(spacing: 12) {
                    Text("Login Failed")
                        .foregroundColor(.red)
                        .fontWeight(.medium)
                    Text(error)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    LoginView()
                }
            case .loggedIn:
                EmptyView() // This case is handled in the main ContentView
            }
        }
    }
    
    @ViewBuilder
    private var connectionIcon: some View {
        switch baseURLProvider.connectionStatus {
        case .pinging:
            ProgressView()
                .scaleEffect(0.8)
        case .reachable:
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
                .font(.title2)
        case .unreachable:
            Image(systemName: "xmark.circle.fill")
                .foregroundColor(.red)
                .font(.title2)
        }
    }
    
    private var connectionStatusText: String {
        switch baseURLProvider.connectionStatus {
        case .pinging:
            return "Testing connection..."
        case .reachable:
            return "Server is reachable"
        case .unreachable:
            return "Server is unreachable"
        }
    }
    
    private var connectionBackgroundColor: Color {
        switch baseURLProvider.connectionStatus {
        case .pinging:
            return Color.blue.opacity(0.1)
        case .reachable:
            return Color.green.opacity(0.1)
        case .unreachable:
            return Color.red.opacity(0.1)
        }
    }
}

struct PhotoGalleryView: View {
    let user: User
    @StateObject private var baseURLProvider = BaseURLProvider.shared
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showingImagePicker = false
    @State private var selectedPhotoForViewing: Photo?
    @State private var showingFullScreenImage = false
    
    var body: some View {
        VStack(spacing: 0) {
            // Header with user info and logout
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Welcome, \(user.username)")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        if !baseURLProvider.photos.isEmpty {
                            Text("\(baseURLProvider.photos.count) photos")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }
                    
                    Spacer()
                    
                    Button("Logout") {
                        baseURLProvider.logout()
                    }
                    .buttonStyle(.bordered)
                }
                
                // Upload and Refresh buttons
                HStack(spacing: 12) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images,
                        photoLibrary: .shared()
                    ) {
                        Label("Upload Photo", systemImage: "plus")
                            .font(.caption)
                    }
                    .buttonStyle(.borderedProminent)
                    .onChange(of: selectedPhoto) { _, newValue in
                        if let newValue {
                            uploadSelectedPhoto(newValue)
                        }
                    }
                    
                    Button("Refresh") {
                        baseURLProvider.loadPhotos()
                    }
                    .buttonStyle(.bordered)
                    .font(.caption)
                    
                    if baseURLProvider.isUploading {
                        ProgressView()
                            .scaleEffect(0.7)
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            
            Divider()
            
            // Photo Gallery
            if baseURLProvider.isLoadingPhotos {
                VStack {
                    Spacer()
                    ProgressView("Loading photos...")
                    Spacer()
                }
            } else if baseURLProvider.photos.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "photo.on.rectangle")
                        .font(.system(size: 60))
                        .foregroundColor(.secondary)
                    Text("No Photos")
                        .font(.title2)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                    Text("Tap 'Upload Photo' to add your first photo")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
            } else {
                ScrollView {
                    LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 1), count: 3), spacing: 1) {
                        ForEach(baseURLProvider.photos) { photo in
                            PhotoGridItem(photo: photo) {
                                selectedPhotoForViewing = photo
                                showingFullScreenImage = true
                            }
                        }
                    }
                    .padding(.horizontal, 1)
                }
            }
        }
        .navigationBarHidden(true)
        .fullScreenCover(isPresented: $showingFullScreenImage) {
            if let selectedPhoto = selectedPhotoForViewing {
                FullScreenImageView(photo: selectedPhoto) {
                    showingFullScreenImage = false
                }
            }
        }
    }
    
    private func uploadSelectedPhoto(_ item: PhotosPickerItem) {
        Task {
            if let data = try? await item.loadTransferable(type: Data.self) {
                let filename = item.itemIdentifier ?? "photo_\(Date().timeIntervalSince1970).jpg"
                baseURLProvider.uploadPhoto(imageData: data, filename: filename)
            }
        }
    }
}

struct PhotoGridItem: View {
    let photo: Photo
    let onTap: () -> Void
    @State private var imageData: Data?
    @State private var isLoading = true
    
    var body: some View {
        Button(action: onTap) {
            GeometryReader { geometry in
                ZStack {
                    Rectangle()
                        .fill(Color(.systemGray6))
                    
                    if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                        Image(uiImage: uiImage)
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: geometry.size.width, height: geometry.size.height)
                            .clipped()
                    } else if isLoading {
                        ProgressView()
                            .scaleEffect(0.6)
                    } else {
                        VStack(spacing: 4) {
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                                .font(.title2)
                            Text("Failed")
                                .font(.caption2)
                                .foregroundColor(.gray)
                        }
                    }
                }
            }
            .aspectRatio(1, contentMode: .fit)
        }
        .buttonStyle(PlainButtonStyle())
        .task {
            await loadThumbnail()
        }
    }
    
    private func loadThumbnail() async {
        let thumbnailURL = BaseURLProvider.shared.getThumbnailURL(filename: photo.filename)
        
        guard let token = BaseURLProvider.shared.getAccessToken() else {
            print("No access token available for thumbnail: \(photo.filename)")
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        print("Loading thumbnail for: \(photo.filename)")
        print("Thumbnail URL: \(thumbnailURL.absoluteString)")
        
        var request = URLRequest(url: thumbnailURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 10.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Thumbnail response status: \(httpResponse.statusCode) for \(photo.filename), data size: \(data.count) bytes")
                
                if httpResponse.statusCode == 200 && !data.isEmpty {
                    await MainActor.run {
                        self.imageData = data
                        self.isLoading = false
                    }
                } else {
                    print("Thumbnail load failed: HTTP \(httpResponse.statusCode)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } else {
                print("No HTTP response for thumbnail: \(photo.filename)")
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Failed to load thumbnail for \(photo.filename): \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct FullScreenImageView: View {
    let photo: Photo
    let onDismiss: () -> Void
    @State private var imageData: Data?
    @State private var isLoading = true
    @State private var scale: CGFloat = 1.0
    @State private var offset: CGSize = .zero
    @State private var lastOffset: CGSize = .zero
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            if let imageData = imageData, let uiImage = UIImage(data: imageData) {
                Image(uiImage: uiImage)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .scaleEffect(scale)
                    .offset(offset)
                    .clipped()
                    .gesture(
                        MagnificationGesture()
                            .onChanged { value in
                                scale = max(1.0, min(value, 5.0))
                            }
                            .simultaneously(with:
                                DragGesture()
                                    .onChanged { value in
                                        offset = CGSize(
                                            width: lastOffset.width + value.translation.width,
                                            height: lastOffset.height + value.translation.height
                                        )
                                    }
                                    .onEnded { _ in
                                        lastOffset = offset
                                    }
                            )
                    )
                    .onTapGesture(count: 2) {
                        withAnimation(.spring()) {
                            if scale > 1.0 {
                                scale = 1.0
                                offset = .zero
                                lastOffset = .zero
                            } else {
                                scale = 2.0
                            }
                        }
                    }
            } else if isLoading {
                VStack(spacing: 16) {
                    ProgressView()
                        .scaleEffect(1.5)
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    Text("Loading full image...")
                        .foregroundColor(.white)
                        .font(.caption)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "photo")
                        .foregroundColor(.white)
                        .font(.system(size: 60))
                    Text("Failed to load image")
                        .foregroundColor(.white)
                        .font(.title2)
                }
            }
            
            // Close button
            VStack {
                HStack {
                    Spacer()
                    Button(action: onDismiss) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title)
                            .foregroundColor(.white)
                            .background(Color.black.opacity(0.5))
                            .clipShape(Circle())
                    }
                    .padding()
                }
                Spacer()
            }
            
            // Photo info overlay
            VStack {
                Spacer()
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(photo.originalName)
                            .font(.headline)
                            .foregroundColor(.white)
                        Text("Uploaded: \(photo.uploadDate)")
                            .font(.caption)
                            .foregroundColor(.white.opacity(0.8))
                        if let metadata = photo.metadata {
                            if let width = metadata.width, let height = metadata.height {
                                Text("\(width) × \(height)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                            if let cameraMake = metadata.cameraMake, let cameraModel = metadata.cameraModel {
                                Text("\(cameraMake) \(cameraModel)")
                                    .font(.caption)
                                    .foregroundColor(.white.opacity(0.8))
                            }
                        }
                    }
                    Spacer()
                }
                .padding()
                .background(
                    LinearGradient(
                        gradient: Gradient(colors: [Color.black.opacity(0.8), Color.clear]),
                        startPoint: .bottom,
                        endPoint: .top
                    )
                )
            }
        }
        .task {
            await loadFullImage()
        }
    }
    
    private func loadFullImage() async {
        let imageURL = BaseURLProvider.shared.getPhotoURL(filename: photo.filename)
        
        guard let token = BaseURLProvider.shared.getAccessToken() else {
            await MainActor.run {
                self.isLoading = false
            }
            return
        }
        
        var request = URLRequest(url: imageURL)
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 30.0
        
        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            
            if let httpResponse = response as? HTTPURLResponse {
                print("Full image response status: \(httpResponse.statusCode) for \(photo.filename)")
                
                if httpResponse.statusCode == 200 && !data.isEmpty {
                    await MainActor.run {
                        self.imageData = data
                        self.isLoading = false
                    }
                } else {
                    print("Full image load failed: HTTP \(httpResponse.statusCode)")
                    await MainActor.run {
                        self.isLoading = false
                    }
                }
            } else {
                await MainActor.run {
                    self.isLoading = false
                }
            }
        } catch {
            print("Failed to load full image for \(photo.filename): \(error.localizedDescription)")
            await MainActor.run {
                self.isLoading = false
            }
        }
    }
}

struct LoginView: View {
    @State private var username = ""
    @State private var password = ""
    
    var body: some View {
        VStack(spacing: 12) {
            TextField("Username", text: $username)
                .textFieldStyle(.roundedBorder)
                .autocapitalization(.none)
                .disableAutocorrection(true)
            
            SecureField("Password", text: $password)
                .textFieldStyle(.roundedBorder)
            
            Button("Login") {
                BaseURLProvider.shared.login(username: username, password: password)
            }
            .buttonStyle(.borderedProminent)
            .disabled(username.isEmpty || password.isEmpty)
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}
