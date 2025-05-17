import SwiftUI
import UniformTypeIdentifiers
import AVKit

// Player view model to retain the AVPlayer instance
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    private var currentURL: URL?
    
    func preparePlayer(for url: URL) {
        // Store the URL we're preparing
        currentURL = url
        
        // Create asset with proper options for network access
        let asset = AVAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Create player and set it
        self.player = AVPlayer(playerItem: playerItem)
        
        // Auto-play when ready
        player?.play()
    }
    
    deinit {
        // Clean up player
        player?.pause()
        player = nil
    }
}

struct SimpleButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Material.ultraThinMaterial)
            .cornerRadius(8)
    }
}

extension View {
    func simpleButtonStyle() -> some View {
        self.modifier(SimpleButtonStyle())
    }
}

struct AppView: View {
    @StateObject private var documentViewModel = Document.ViewActor()
    @State private var isImporting = false
    @State private var showingAPIKeyAlert = false
    @State private var tempAPIKey = ""
    @State private var selectedDocument: Document.Model?
    @StateObject private var playerViewModel = PlayerViewModel()
    @State private var isDropTargeted = false
    
    var body: some View {
        ZStack {
            HStack(spacing: 0) {
                // Left sidebar with documents
                Sidebar(
                    documentViewModel: documentViewModel,
                    selectedDocument: $selectedDocument,
                    playerViewModel: playerViewModel,
                    isImporting: $isImporting
                )
                .frame(width: 350)
                .background(Material.regular)
                
                // Right side content view
                if let selectedDoc = selectedDocument {
                    // Document content display
                    DetailView(
                        document: selectedDoc,
                        playerViewModel: playerViewModel
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Material.regular)
                } else {
                    // Placeholder when no document is selected
                    PlaceholderView()
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Material.regular)
                }
            }
            
            // Drag and drop overlay
            if isDropTargeted {
                ZStack {
                    Rectangle()
                        .fill(Color.blue.opacity(0.25))
                        .overlay(
                            RoundedRectangle(cornerRadius: 20)
                                .strokeBorder(Color.blue, lineWidth: 4, antialiased: true)
                                .padding(40)
                        )
                    
                    VStack(spacing: 20) {
                        Image(systemName: "arrow.down.doc.fill")
                            .font(.system(size: 60))
                            .foregroundColor(.white)
                        
                        Text("Drop Files to Import")
                            .font(.system(size: 24, weight: .bold))
                            .foregroundColor(.white)
                        
                        Text("Release to add files to your library")
                            .font(.system(size: 16))
                            .foregroundColor(.white.opacity(0.9))
                    }
                    .padding(50)
                    .background(Material.ultraThick)
                    .cornerRadius(25)
                    .shadow(color: Color.black.opacity(0.5), radius: 15, x: 0, y: 5)
                }
                .edgesIgnoringSafeArea(.all)
                .transition(.opacity)
                .animation(.easeInOut(duration: 0.2), value: isDropTargeted)
            }
        }
        .onDrop(of: [.fileURL], isTargeted: $isDropTargeted) { providers in
            Task {
                // Set analyzing flag immediately
                DispatchQueue.main.async {
                    self.documentViewModel.isAnalyzingContent = true
                }
                
                // Process the dropped items
                await processDroppedItems(providers)
                
                // Generate embeddings if API key is set
                if !documentViewModel.apiKey.isEmpty {
                    await documentViewModel.generateEmbeddings()
                }
            }
            return true
        }
        .fileImporter(
            isPresented: $isImporting,
            allowedContentTypes: Document.Handler.supportedTypes,
            allowsMultipleSelection: true
        ) { result in
            do {
                let urls = try result.get()
                
                Task {
                    // Set analyzing flag immediately
                    DispatchQueue.main.async {
                        self.documentViewModel.isAnalyzingContent = true
                    }
                    
                    // Process multiple files concurrently with TaskGroup
                    await withTaskGroup(of: (Document.Model?, Error?).self) { group in
                        for url in urls {
                            group.addTask {
                                if url.startAccessingSecurityScopedResource() {
                                    defer { url.stopAccessingSecurityScopedResource() }
                                    
                                    do {
                                        // Get file type
                                        let fileType = Document.Handler.getFileType(for: url)
                                        
                                        // Create a security-scoped bookmark for the file
                                        var securityBookmark: Data? = nil
                                        do {
                                            securityBookmark = try url.bookmarkData(options: .minimalBookmark, 
                                                                             includingResourceValuesForKeys: nil, 
                                                                             relativeTo: nil)
                                        } catch {
                                            print("Failed to create security bookmark for \(url.lastPathComponent): \(error)")
                                        }
                                        
                                        // Extract text content
                                        let text = try await Document.Handler.extractText(from: url)
                                        
                                        // Extract metadata
                                        let metadata = try await Document.Handler.extractMetadata(from: url)
                                        
                                        // Handle thumbnails for multimedia files
                                        var thumbnailURL: URL? = nil
                                        
                                        if fileType == .image {
                                            // For images, we need to create a proper bookmark and use the original file as the thumbnail
                                            thumbnailURL = url
                                            
                                            // Make sure we have a security bookmark since we'll need it to access the image
                                            if securityBookmark == nil {
                                                do {
                                                    securityBookmark = try url.bookmarkData(options: [.withSecurityScope, .securityScopeAllowOnlyReadAccess], 
                                                                                    includingResourceValuesForKeys: nil, 
                                                                                    relativeTo: nil)
                                                } catch {
                                                    print("Failed to create security bookmark for image: \(error)")
                                                }
                                            }
                                        } else if fileType == .video {
                                            // For videos, extract a thumbnail
                                            if let thumbnail = try? await Document.Handler.extractVideoThumbnail(url: url) {
                                                // Save the thumbnail to the app's documents directory
                                                let thumbnailsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                                    .appendingPathComponent("Thumbnails", isDirectory: true)
                                                
                                                // Create the thumbnails directory if it doesn't exist
                                                try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
                                                
                                                // Generate a unique filename for the thumbnail
                                                let thumbnailFileName = UUID().uuidString + ".jpeg"
                                                let thumbnailPath = thumbnailsDir.appendingPathComponent(thumbnailFileName)
                                                
                                                // Resize the thumbnail to a smaller size
                                                let resizedThumbnail = thumbnail.thumbnailImage(maxSize: 400)
                                                
                                                // Convert NSImage to JPEG data and save to file
                                                if let tiffData = resizedThumbnail.tiffRepresentation,
                                                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                                                   let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                                                    try jpegData.write(to: thumbnailPath)
                                                    thumbnailURL = thumbnailPath
                                                }
                                            }
                                        }
                                        
                                        let document = Document.Model(
                                            name: url.lastPathComponent,
                                            text: text,
                                            embedding: nil,
                                            url: url,
                                            fileType: fileType,
                                            thumbnailURL: thumbnailURL,
                                            securityScopedBookmark: securityBookmark,
                                            metadata: metadata
                                        )
                                        
                                        return (document, nil)
                                    } catch {
                                        return (nil, error)
                                    }
                                } else {
                                    return (nil, NSError(domain: "ContentView", code: 1, userInfo: [NSLocalizedDescriptionKey: "Unable to access security-scoped resource"]))
                                }
                            }
                        }
                        
                        // Collect results as they complete
                        var documentsToAdd: [Document.Model] = []
                        for await (document, error) in group {
                            if let document = document {
                                documentsToAdd.append(document)
                            } else if let error = error {
                                print("Error processing document: \(error)")
                            }
                        }
                        
                        // Add all documents to the store at once
                        DispatchQueue.main.async {
                            for document in documentsToAdd {
                                self.documentViewModel.addDocument(document)
                            }
                            self.documentViewModel.isAnalyzingContent = false
                        }
                    }
                    
                    // Generate embeddings if API key is set
                    if !documentViewModel.apiKey.isEmpty {
                        await documentViewModel.generateEmbeddings()
                    }
                }
            } catch {
                print("Error importing files: \(error)")
            }
        }
        .alert("OpenAI API Key", isPresented: $showingAPIKeyAlert) {
            TextField("Enter your API key", text: $tempAPIKey)
                .foregroundColor(.primary)
            
            Button("Save") {
                documentViewModel.apiKey = tempAPIKey
            }
            
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Please enter your OpenAI API key to generate embeddings.")
        }
        .onAppear {
            if documentViewModel.apiKey.isEmpty {
                showingAPIKeyAlert = true
            }
            
            // Register for Import Files notification from menu
            NotificationCenter.default.addObserver(forName: NSNotification.Name("ImportFiles"), 
                                                  object: nil, 
                                                  queue: .main) { _ in
                isImporting = true
            }
        }
        .onDisappear {
            // Remove notification observer
            NotificationCenter.default.removeObserver(self, 
                                                    name: NSNotification.Name("ImportFiles"), 
                                                    object: nil)
        }
    }
    
    private func processDroppedItems(_ providers: [NSItemProvider]) async {
        // Create a task group to process multiple files concurrently
        await withTaskGroup(of: (Document.Model?, Error?).self) { group in
            for provider in providers {
                group.addTask {
                    return await withCheckedContinuation { continuation in
                        provider.loadItem(forTypeIdentifier: UTType.fileURL.identifier, options: nil) { item, error in
                            if let error = error {
                                continuation.resume(returning: (nil, error))
                                return
                            }
                            
                            guard let data = item as? Data, 
                                  let url = URL(dataRepresentation: data, relativeTo: nil) else {
                                continuation.resume(returning: (nil, NSError(
                                    domain: "AppView", 
                                    code: 1, 
                                    userInfo: [NSLocalizedDescriptionKey: "Invalid dropped item"]
                                )))
                                return
                            }
                            
                            // Copy the file to a temporary location that we can access more reliably
                            let tempDir = FileManager.default.temporaryDirectory
                            let copyURL = tempDir.appendingPathComponent(url.lastPathComponent)
                            
                            do {
                                // If a file already exists at the destination, remove it
                                if FileManager.default.fileExists(atPath: copyURL.path) {
                                    try FileManager.default.removeItem(at: copyURL)
                                }
                                
                                // Copy the file
                                try FileManager.default.copyItem(at: url, to: copyURL)
                                
                                // Process the file using existing methods
                                Task {
                                    do {
                                        // Get file type
                                        let fileType = Document.Handler.getFileType(for: copyURL)
                                        
                                        // Extract text content
                                        let text = try await Document.Handler.extractText(from: copyURL)
                                        
                                        // Extract metadata
                                        let metadata = try await Document.Handler.extractMetadata(from: copyURL)
                                        
                                        // Handle thumbnails for multimedia files
                                        var thumbnailURL: URL? = nil
                                        
                                        if fileType == .image {
                                            // For images, use the original file as the thumbnail
                                            thumbnailURL = copyURL
                                        } else if fileType == .video {
                                            // For videos, extract a thumbnail
                                            if let thumbnail = try? await Document.Handler.extractVideoThumbnail(url: copyURL) {
                                                // Save the thumbnail to the app's documents directory
                                                let thumbnailsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                                                    .appendingPathComponent("Thumbnails", isDirectory: true)
                                                
                                                // Create the thumbnails directory if it doesn't exist
                                                try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
                                                
                                                // Generate a unique filename for the thumbnail
                                                let thumbnailFileName = UUID().uuidString + ".jpeg"
                                                let thumbnailPath = thumbnailsDir.appendingPathComponent(thumbnailFileName)
                                                
                                                // Resize the thumbnail to a smaller size
                                                let resizedThumbnail = thumbnail.thumbnailImage(maxSize: 400)
                                                
                                                // Convert NSImage to JPEG data and save to file
                                                if let tiffData = resizedThumbnail.tiffRepresentation,
                                                   let bitmapRep = NSBitmapImageRep(data: tiffData),
                                                   let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) {
                                                    try jpegData.write(to: thumbnailPath)
                                                    thumbnailURL = thumbnailPath
                                                }
                                            }
                                        }
                                        
                                        let document = Document.Model(
                                            name: url.lastPathComponent,
                                            text: text,
                                            embedding: nil,
                                            url: copyURL,
                                            fileType: fileType,
                                            thumbnailURL: thumbnailURL,
                                            securityScopedBookmark: nil, // No need for bookmark with temp files
                                            metadata: metadata
                                        )
                                        
                                        continuation.resume(returning: (document, nil))
                                    } catch {
                                        continuation.resume(returning: (nil, error))
                                    }
                                }
                            } catch {
                                print("Error copying dropped file: \(error)")
                                continuation.resume(returning: (nil, NSError(
                                    domain: "AppView", 
                                    code: 3, 
                                    userInfo: [NSLocalizedDescriptionKey: "Failed to copy dropped file: \(error.localizedDescription)"]
                                )))
                            }
                        }
                    }
                }
            }
            
            // Collect results as they complete
            var documentsToAdd: [Document.Model] = []
            for await (document, error) in group {
                if let document = document {
                    documentsToAdd.append(document)
                } else if let error = error {
                    print("Error processing dropped document: \(error)")
                }
            }
            
            // Add all documents to the store at once
            DispatchQueue.main.async {
                for document in documentsToAdd {
                    self.documentViewModel.addDocument(document)
                }
                self.documentViewModel.isAnalyzingContent = false
            }
        }
    }
    
    // Helper functions
    private func fileTypeIcon(for fileType: Document.Handler.FileType) -> String {
        switch fileType {
        case .text:
            return "doc.text"
        case .pdf:
            return "doc.richtext"
        case .image:
            return "photo"
        case .video:
            return "film"
        case .audio:
            return "waveform"
        case .unknown:
            return "doc"
        }
    }
    
    private func fileTypeName(for fileType: Document.Handler.FileType) -> String {
        switch fileType {
        case .text:
            return "Text"
        case .pdf:
            return "PDF"
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .unknown:
            return "Unknown"
        }
    }
}

// MARK: - Sidebar View
extension AppView {
    struct Sidebar: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var selectedDocument: Document.Model?
        @ObservedObject var playerViewModel: PlayerViewModel
        @Binding var isImporting: Bool
        @State private var showingAPIKeyAlert = false
        @State private var tempAPIKey = ""
        
        var body: some View {
            VStack(spacing: 0) {
                // Header with title and toolbar buttons
                SidebarHeader(
                    documentViewModel: documentViewModel,
                    isImporting: $isImporting
                )
                
                // API Key and Search
                SearchBar(
                    documentViewModel: documentViewModel,
                    showingAPIKeyAlert: $showingAPIKeyAlert,
                    tempAPIKey: $tempAPIKey
                )
                
                // Document List
                DocumentList(
                    documentViewModel: documentViewModel,
                    selectedDocument: $selectedDocument,
                    playerViewModel: playerViewModel
                )
                
                // Status and Control Buttons
                StatusFooter(documentViewModel: documentViewModel)
            }
            .alert("OpenAI API Key", isPresented: $showingAPIKeyAlert) {
                TextField("Enter your API key", text: $tempAPIKey)
                    .foregroundColor(.primary)
                
                Button("Save") {
                    documentViewModel.apiKey = tempAPIKey
                }
                
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enter your OpenAI API key to generate embeddings.")
            }
        }
    }
    
    struct SidebarHeader: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var isImporting: Bool
        
        var body: some View {
            HStack {
                Text("Embeddings")
                    .font(.title)
                    .foregroundColor(.primary)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    documentViewModel.clearAllDocuments()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .disabled(documentViewModel.documents.isEmpty)
                .opacity(documentViewModel.documents.isEmpty ? 0.5 : 1)
                
                Button(action: {
                    isImporting = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding(.trailing)
            }
            .padding(.top)
            .padding(.bottom, 8)
        }
    }
    
    struct SearchBar: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var showingAPIKeyAlert: Bool
        @Binding var tempAPIKey: String
        @State private var debouncedText: String = ""
        @State private var debounceTask: Task<Void, Never>?
        
        var body: some View {
            HStack {
                Button(action: {
                    tempAPIKey = documentViewModel.apiKey
                    showingAPIKeyAlert = true
                }) {
                    Label("API Key", systemImage: "key.fill")
                        .foregroundColor(.primary)
                        .simpleButtonStyle()
                }
                .buttonStyle(.plain)
                .padding(.leading)
                
                Spacer()
                
                TextField("Search...", text: $documentViewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Material.bar)
                    .cornerRadius(8)
                    .onChange(of: documentViewModel.searchQuery) { newText in
                        // Cancel any previous debounce task
                        debounceTask?.cancel()
                        
                        // Create a new debounce task with a longer delay for better performance
                        debounceTask = Task {
                            do {
                                // Increase delay to 800ms to reduce frequency of searches
                                try await Task.sleep(nanoseconds: 800_000_000)
                                
                                // If task wasn't cancelled during the sleep, update the debounced text
                                if !Task.isCancelled {
                                    debouncedText = newText
                                    await documentViewModel.performSearch()
                                }
                            } catch {
                                // Task was cancelled or failed, do nothing
                            }
                        }
                    }
                    .background(Material.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.trailing)
            }
            .padding(.bottom)
        }
    }
    
    struct DocumentList: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var selectedDocument: Document.Model?
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(documentViewModel.sortedResults.isEmpty ? documentViewModel.documents : documentViewModel.sortedResults) { document in
                        DocumentListItem(
                            document: document,
                            isSelected: selectedDocument?.id == document.id,
                            documentViewModel: documentViewModel,
                            onSelect: {
                                // Stop accessing the previous document if there was one
                                if let prevDoc = selectedDocument, prevDoc.isMultimedia {
                                    prevDoc.stopAccessingSecurityScopedResource()
                                }
                                
                                selectedDocument = document
                                
                                // Start accessing the new document if it's multimedia
                                if document.isMultimedia {
                                    _ = document.startAccessingSecurityScopedResource()
                                }
                                
                                // Prepare player if it's a video
                                if document.fileType == .video {
                                    playerViewModel.preparePlayer(for: document.url)
                                }
                            }
                        )
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
        }
    }
    
    struct DocumentListItem: View {
        let document: Document.Model
        let isSelected: Bool
        @ObservedObject var documentViewModel: Document.ViewActor
        let onSelect: () -> Void
        @State private var thumbnail: NSImage?
        @State private var isLoadingThumbnail: Bool = false
        
        var body: some View {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    // Document type icon or thumbnail
                    if document.isMultimedia {
                        ZStack {
                            Rectangle()
                                .fill(Material.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                            
                            if let thumbnailImage = thumbnail {
                                Image(nsImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                            } else {
                                if isLoadingThumbnail {
                                    ProgressView()
                                        .frame(width: 40, height: 40)
                                } else {
                                    Image(systemName: fileTypeIcon(for: document.fileType))
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .onAppear {
                            loadThumbnail()
                        }
                        .onDisappear {
                            // Stop accessing when the view disappears
                            if document.isMultimedia {
                                document.stopAccessingSecurityScopedResource()
                            }
                            
                            // Clear thumbnail to free memory when scrolled out of view
                            thumbnail = nil
                        }
                    } else {
                        Image(systemName: fileTypeIcon(for: document.fileType))
                            .font(.system(size: 20))
                            .frame(width: 40, height: 40)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(document.text.prefix(60) + (document.text.count > 60 ? "..." : ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            if !documentViewModel.searchQuery.isEmpty {
                                if documentViewModel.searchEmbedding != nil && document.embedding != nil {
                                    // Show similarity score from embedding if available
                                    let similarity = documentViewModel.embeddingService.cosineSimilarity(
                                        between: documentViewModel.searchEmbedding!, 
                                        and: document.embedding!
                                    )
                                    Text("Similarity: \(Int(similarity * 100))%")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Material.ultraThinMaterial)
                                        )
                                        .foregroundColor(
                                            similarity > 0.8 ? .green :
                                            similarity > 0.5 ? .orange : 
                                            .red
                                        )
                                } else if documentViewModel.searchEmbedding == nil && 
                                          (document.name.lowercased().contains(documentViewModel.searchQuery.lowercased()) ||
                                           document.text.lowercased().contains(documentViewModel.searchQuery.lowercased())) {
                                    // Show text match badge for simple text search
                                    Text("Match")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Material.ultraThinMaterial)
                                        )
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            if document.isEmbedded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Material.ultraThickMaterial : Material.ultraThinMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
        }
        
        private func loadThumbnail() {
            // Only attempt to load if we don't already have a thumbnail and aren't currently loading
            guard thumbnail == nil && !isLoadingThumbnail else { return }
            
            isLoadingThumbnail = true
            
            // Start accessing the resource if it's a multimedia file
            if document.isMultimedia {
                _ = document.startAccessingSecurityScopedResource()
            }
            
            // Use a background task to load the thumbnail
            Task {
                if let image = document.thumbnail {
                    // Create a tiny thumbnail for the list item
                    let smallThumbnail = image.thumbnailImage(maxSize: 60)
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        self.thumbnail = smallThumbnail
                        self.isLoadingThumbnail = false
                    }
                } else {
                    DispatchQueue.main.async {
                        self.isLoadingThumbnail = false
                    }
                }
            }
        }
    }
    
    struct StatusFooter: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        
        var body: some View {
            HStack {
                if documentViewModel.isGeneratingEmbeddings {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.horizontal)
                    Text("Generating embeddings...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if documentViewModel.isAnalyzingContent {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.horizontal)
                    Text("Analyzing content...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(documentViewModel.documents.count) documents loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await documentViewModel.generateEmbeddings()
                    }
                }) {
                    Text("Generate Embeddings")
                        .foregroundColor(.primary)
                        .simpleButtonStyle()
                }
                .disabled(documentViewModel.documents.isEmpty || documentViewModel.apiKey.isEmpty || documentViewModel.isGeneratingEmbeddings)
                .opacity(documentViewModel.documents.isEmpty || documentViewModel.apiKey.isEmpty || documentViewModel.isGeneratingEmbeddings ? 0.5 : 1)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
}

// MARK: - Detail View
extension AppView {
    struct DetailView: View {
        let document: Document.Model
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document Header
                    DocumentHeader(document: document)
                    
                    // File Type Badge
                    FileTypeBadge(fileType: document.fileType)
                    
                    Divider()
                    
                    // Multimedia Content Preview
                    if document.isMultimedia {
                        MediaPreview(document: document, playerViewModel: playerViewModel)
                    }
                    
                    // Metadata Section
                    MetadataSection(metadata: document.metadata)
            
                    // Text Content
                    ContentSection(text: document.text)
                }
                .padding()
            }
        }
    }
    
    struct DocumentHeader: View {
        let document: Document.Model
        
        var body: some View {
            HStack {
                Text(document.name)
                    .font(.title)
                    .bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                if document.isEmbedded {
                    Label("Embedded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                } else {
                    Label("Not Embedded", systemImage: "circle")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }
    
    struct FileTypeBadge: View {
        let fileType: Document.Handler.FileType
        
        var body: some View {
            HStack {
                Label(
                    fileTypeName(for: fileType),
                    systemImage: fileTypeIcon(for: fileType)
                )
                .foregroundColor(.secondary)
                .padding(6)
                .background(Material.ultraThinMaterial)
                .cornerRadius(8)
                
                Spacer()
            }
        }
    }
    
    struct MetadataSection: View {
        let metadata: [String: String]
        @State private var isExpanded: Bool = true
        
        var body: some View {
            VStack(alignment: .leading) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Text("Metadata")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(metadata.keys.sorted(), id: \.self) { key in
                            if let value = metadata[key] {
                                VStack(alignment: .leading) {
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(value)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Material.ultraThinMaterial)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
    
    struct MediaPreview: View {
        let document: Document.Model
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Media Preview")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Group {
                    if document.fileType == .image {
                        ImagePreview(document: document)
                    } else if document.fileType == .video {
                        VideoPreview(document: document, playerViewModel: playerViewModel)
                    } else if document.fileType == .audio {
                        AudioPreview()
                    }
                }
                .frame(minHeight: 300)
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
    
    struct ImagePreview: View {
        let document: Document.Model
        @State private var displayImage: NSImage?
        
        var body: some View {
            ZStack {
                Rectangle()
                    .fill(Material.thin)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                
                if let image = displayImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Unable to load image")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                loadImage()
            }
            .onDisappear {
                document.stopAccessingSecurityScopedResource()
                displayImage = nil
            }
        }
        
        private func loadImage() {
            // Start accessing the resource
            let _ = document.startAccessingSecurityScopedResource()
            
            // Load the image, resize and cache for display
            if let image = document.thumbnail {
                let maxDimension: CGFloat = 800
                let ratio = min(maxDimension / image.size.width, maxDimension / image.size.height)
                if ratio < 1.0 {
                    // Only resize if the image is larger than our target size
                    displayImage = image.resized(to: NSSize(
                        width: image.size.width * ratio,
                        height: image.size.height * ratio
                    ))
                } else {
                    displayImage = image
                }
            }
        }
    }
    
    struct VideoPreview: View {
        let document: Document.Model
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            if let player = playerViewModel.player {
                VideoPlayer(player: player)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                        document.stopAccessingSecurityScopedResource()
                    }
            } else {
                Text("Video could not be loaded")
                    .foregroundColor(.secondary)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Material.thin)
                    .cornerRadius(8)
            }
        }
    }
    
    struct AudioPreview: View {
        var body: some View {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("Audio Player")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Material.thin)
            .cornerRadius(8)
        }
    }
    
    struct ContentSection: View {
        let text: String
        
        var body: some View {
            Text("Content")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Material.ultraThinMaterial)
                .cornerRadius(8)
        }
    }
}

// MARK: - Placeholder View
extension AppView {
    struct PlaceholderView: View {
        var body: some View {
            VStack {
                Spacer()
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Select a document to view its content")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                Spacer()
            }
        }
    }
}

// MARK: - Helper Methods
extension AppView {
    static func fileTypeIcon(for fileType: Document.Handler.FileType) -> String {
        switch fileType {
        case .text:
            return "doc.text"
        case .pdf:
            return "doc.richtext"
        case .image:
            return "photo"
        case .video:
            return "film"
        case .audio:
            return "waveform"
        case .unknown:
            return "doc"
        }
    }
    
    static func fileTypeName(for fileType: Document.Handler.FileType) -> String {
        switch fileType {
        case .text:
            return "Text"
        case .pdf:
            return "PDF"
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .unknown:
            return "Unknown"
        }
    }
}

// Forwarding helpers from instance methods to static methods
private func fileTypeIcon(for fileType: Document.Handler.FileType) -> String {
    AppView.fileTypeIcon(for: fileType)
}

private func fileTypeName(for fileType: Document.Handler.FileType) -> String {
    AppView.fileTypeName(for: fileType)
} 
