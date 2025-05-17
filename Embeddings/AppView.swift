import SwiftUI
import UniformTypeIdentifiers
import AVKit

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
                                                
                                                // Generate a unique filename for the thumbnail based on original file and UUID
                                                let fileName = url.deletingPathExtension().lastPathComponent
                                                let thumbnailFileName = "\(fileName)-\(UUID().uuidString).jpeg"
                                                let thumbnailPath = thumbnailsDir.appendingPathComponent(thumbnailFileName)
                                                
                                                print("Creating thumbnail at: \(thumbnailPath.path)")
                                                
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
                                                
                                                // Generate a unique filename for the thumbnail based on original file and UUID
                                                let fileName = copyURL.deletingPathExtension().lastPathComponent
                                                let thumbnailFileName = "\(fileName)-\(UUID().uuidString).jpeg"
                                                let thumbnailPath = thumbnailsDir.appendingPathComponent(thumbnailFileName)
                                                
                                                print("Creating thumbnail at: \(thumbnailPath.path)")
                                                
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
}
