import Foundation
import SwiftUI
import CorePersistence

extension Document {
    @MainActor
    class ViewActor: ObservableObject {
        
        @FileStorage(
            .appDocuments,
            directory: "Documents",
            coder: .json
        )
        var documents: IdentifierIndexingArrayOf<Document.Model> = []
        
        @Published var searchQuery: String = ""
        @Published var searchEmbedding: [Float]?
        @Published var sortedResults: IdentifierIndexingArrayOf<Document.Model> = []
        @Published var isGeneratingEmbeddings: Bool = false
        @Published var isAnalyzingContent: Bool = false
        @Published var apiKey: String = "" {
            didSet {
                embeddingService.setAPIKey(apiKey)
                multimodalService.setAPIKey(apiKey)
                UserDefaults.standard.set(apiKey, forKey: "openai_api_key")
                
                // Generate embeddings for all documents when API key is set
                if !apiKey.isEmpty && !documents.isEmpty {
                    Task {
                        await generateEmbeddings()
                    }
                }
            }
        }
        
        let embeddingService = Embedding.Service()
        private let multimodalService = Multimodal.Service.shared
        
        init() {
            if let savedKey = UserDefaults.standard.string(forKey: "openai_api_key") {
                apiKey = savedKey
                embeddingService.setAPIKey(savedKey)
                multimodalService.setAPIKey(savedKey)
            }
        }
        
        func addDocument(_ document: Document.Model) {
            documents.append(document)
            
            // We no longer automatically generate embeddings for each document individually
            // since we'll batch process them after all documents are added
        }
        
        func addDocumentFromURL(_ url: URL) async throws {
            isAnalyzingContent = true
            
            // Get file type
            let fileType = Document.Handler.getFileType(for: url)
            
            // Create a security-scoped bookmark for the file
            var securityBookmark: Data? = nil
            if url.startAccessingSecurityScopedResource() {
                defer { url.stopAccessingSecurityScopedResource() }
                
                do {
                    securityBookmark = try url.bookmarkData(options: .minimalBookmark, includingResourceValuesForKeys: nil, relativeTo: nil)
                } catch {
                    print("Failed to create security bookmark for \(url.lastPathComponent): \(error)")
                }
            }
            
            // Extract text content
            let text = try await Document.Handler.extractText(from: url)
            
            // Extract metadata
            let metadata = try await Document.Handler.extractMetadata(from: url)
            
            // Handle thumbnails for multimedia files
            var thumbnailURL: URL? = nil
            
            if fileType == .image {
                // For images, we can use the original file as the thumbnail
                thumbnailURL = url
            } else if fileType == .video {
                // For videos, extract a thumbnail and save it to a temporary file
                if let thumbnail = try? await Document.Handler.extractVideoThumbnail(url: url) {
                    // Save the thumbnail to the app's documents directory
                    let thumbnailsDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
                        .appendingPathComponent("Thumbnails", isDirectory: true)
                    
                    // Create the thumbnails directory if it doesn't exist
                    try? FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
                    
                    // Generate a unique filename for the thumbnail
                    let thumbnailFileName = UUID().uuidString + ".jpeg"
                    let thumbnailPath = thumbnailsDir.appendingPathComponent(thumbnailFileName)
                    
                    // Convert NSImage to JPEG data and save to file
                    if let tiffData = thumbnail.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
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
            
            DispatchQueue.main.async {
                self.documents.append(document)
                self.isAnalyzingContent = false
                
                // Generate embedding
                if !self.apiKey.isEmpty {
                    Task {
                        await self.generateEmbeddingForDocument(at: self.documents.count - 1)
                    }
                }
            }
        }
        
        func removeDocument(at offsets: IndexSet) {
            documents.remove(atOffsets: offsets)
            updateSortedResults()
        }
        
        func clearAllDocuments() {
            documents.removeAll()
            sortedResults.removeAll()
        }
        
        private func generateEmbeddingForDocument(at index: Int) async {
            guard !apiKey.isEmpty, index >= 0 && index < documents.count else { return }
            
            isGeneratingEmbeddings = true
            
            var document = documents[index]
            
            if document.embedding == nil {
                do {
                    // Use fullText instead of just text to include metadata
                    let embedding = try await embeddingService.generateEmbedding(for: document.fullText)
                    document.embedding = embedding
                    
                    self.documents[index] = document
                    self.isGeneratingEmbeddings = false
                    self.updateSortedResults()
                } catch {
                    print("Error generating embedding for \(document.name): \(error)")
                    self.isGeneratingEmbeddings = false
                }
            }
        }
        
        func generateEmbeddings() async {
            guard !apiKey.isEmpty else { return }
            
            isGeneratingEmbeddings = true
            
            // Use async let to process documents concurrently
            await withTaskGroup(of: (Int, [Float]?).self) { group in
                for i in 0..<documents.count where documents[i].embedding == nil {
                    group.addTask {
                        do {
                            // Use fullText instead of just text to include metadata
                            let embedding = try await self.embeddingService.generateEmbedding(for: self.documents[i].fullText)
                            return (i, embedding)
                        } catch {
                            print("Error generating embedding for \(await self.documents[i].name): \(error)")
                            return (i, nil)
                        }
                    }
                }
                
                // Process results as they complete
                for await (index, embedding) in group {
                    if let embedding = embedding {
                        var updatedDoc = self.documents[index]
                        updatedDoc.embedding = embedding
                        self.documents[index] = updatedDoc
                    }
                }
            }
            
            isGeneratingEmbeddings = false
            updateSortedResults()
        }
        
        func performSearch() async {
            // Clear results if search is empty
            guard !searchQuery.isEmpty, !apiKey.isEmpty else {
                // If search is empty, just show all documents without sorting
                DispatchQueue.main.async {
                    self.searchEmbedding = nil
                    self.sortedResults = self.documents
                }
                return
            }
            
            // Skip embedding generation if query is too short
            if searchQuery.count < 3 {
                DispatchQueue.main.async {
                    // For very short queries, do a simple contains match
                    self.searchEmbedding = nil
                    self.sortedResults = self.documents.filter { 
                        $0.name.lowercased().contains(self.searchQuery.lowercased()) ||
                        $0.text.lowercased().contains(self.searchQuery.lowercased())
                    }
                }
                return
            }
            
            do {
                // Generate embeddings for semantic search
                let embedding = try await embeddingService.generateEmbedding(for: searchQuery)
                
                DispatchQueue.main.async {
                    self.searchEmbedding = embedding
                    self.updateSortedResults()
                }
            } catch {
                print("Error generating search embedding: \(error)")
                
                // Fall back to simple text search on error
                DispatchQueue.main.async {
                    self.searchEmbedding = nil
                    self.sortedResults = self.documents.filter { 
                        $0.name.lowercased().contains(self.searchQuery.lowercased()) ||
                        $0.text.lowercased().contains(self.searchQuery.lowercased())
                    }
                }
            }
        }
        
        private func updateSortedResults() {
            guard let searchEmbedding = searchEmbedding else {
                sortedResults = documents
                return
            }
            
            let docsWithEmbeddings = documents.filter { $0.embedding != nil }
            
            sortedResults = docsWithEmbeddings.sorted { doc1, doc2 in
                let similarity1 = embeddingService.cosineSimilarity(between: searchEmbedding, and: doc1.embedding!)
                let similarity2 = embeddingService.cosineSimilarity(between: searchEmbedding, and: doc2.embedding!)
                return similarity1 > similarity2
            }
        }
    }
} 
