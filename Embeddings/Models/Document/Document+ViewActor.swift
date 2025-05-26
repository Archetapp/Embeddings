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
        
        let embeddingService = Embedding.Service()
        private let multimodalService = Multimodal.Service.shared
        
        init() {
            // Listen for document notifications from folder indexing
            NotificationCenter.default.addObserver(
                forName: NSNotification.Name("AddDocument"),
                object: nil,
                queue: .main
            ) { [weak self] notification in
                if let document = notification.object as? Document.Model {
                    self?.addDocument(document)
                }
            }
            
            // Don't initialize models here - let them be initialized lazily when first needed
        }
        
        deinit {
            NotificationCenter.default.removeObserver(self)
        }
        
        func addDocument(_ document: Document.Model) {
            if !documents.contains(where: { $0.url.path == document.url.path }) {
                documents.append(document)
            } else {
                print("Document already exists: \(document.name)")
            }
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
            
            // Extract text content and metadata
            let text = try await Document.Handler.extractText(from: url)
            let metadata = try await Document.Handler.extractMetadata(from: url)
            
            // Generate thumbnail for supported media types
            var thumbnailURL: URL? = nil
            if fileType == .video {
                do {
                    let thumbnail = try await Document.Handler.extractVideoThumbnail(url: url)
                    let thumbnailsDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!.appendingPathComponent("thumbnails")
                    try FileManager.default.createDirectory(at: thumbnailsDir, withIntermediateDirectories: true)
                    
                    let thumbnailPath = thumbnailsDir.appendingPathComponent("\(UUID().uuidString).jpg")
                    if let tiffData = thumbnail.tiffRepresentation,
                       let bitmapRep = NSBitmapImageRep(data: tiffData),
                       let jpegData = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.8]) {
                        try jpegData.write(to: thumbnailPath)
                        thumbnailURL = thumbnailPath
                    }
                } catch {
                    print("Failed to generate video thumbnail: \(error)")
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
                self.addDocument(document)
                self.isAnalyzingContent = false
                
                // Generate embedding using local models after a small delay
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    Task { @MainActor in
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
            guard index >= 0 && index < documents.count else { return }
            
            await MainActor.run {
                isGeneratingEmbeddings = true
            }
            
            var document = documents[index]
            
            if document.embedding == nil {
                do {
                    if document.summary == nil {
                        let summary = try await Embedding.TextGenerationService.shared.summarizeDocument(document.text)
                        document.summary = summary
                    }
                    
                    let embedding = try await embeddingService.generateEmbedding(for: document.fullText)
                    document.embedding = embedding
                    
                    await MainActor.run {
                        self.documents[index] = document
                        self.isGeneratingEmbeddings = false
                        self.updateSortedResults()
                    }
                } catch {
                    print("Error generating embedding for \(document.name): \(error)")
                    await MainActor.run {
                        self.isGeneratingEmbeddings = false
                    }
                }
            }
        }
        
        func generateEmbeddings() async {
            await MainActor.run {
                isGeneratingEmbeddings = true
            }
            
            // Get documents that need embeddings
            let documentsNeedingEmbeddings = documents.enumerated().compactMap { index, document in
                document.embedding == nil ? (index, document) : nil
            }
            
            // Process documents in batches concurrently
            let batchSize = 5 // Process 5 documents at a time
            
            for i in stride(from: 0, to: documentsNeedingEmbeddings.count, by: batchSize) {
                let endIndex = min(i + batchSize, documentsNeedingEmbeddings.count)
                let batch = Array(documentsNeedingEmbeddings[i..<endIndex])
                
                await withTaskGroup(of: (Int, [Float]?, String?).self) { group in
                    for (index, document) in batch {
                        group.addTask {
                            do {
                                var summary: String? = document.summary
                                if summary == nil {
                                    summary = try await Embedding.TextGenerationService.shared.summarizeDocument(document.text)
                                }
                                
                                let embedding = try await self.embeddingService.generateEmbedding(for: document.fullText)
                                return (index, embedding, summary)
                            } catch {
                                print("Error generating embedding for \(document.name): \(error)")
                                return (index, nil, nil)
                            }
                        }
                    }
                    
                    // Collect results and update documents
                    for await (index, embedding, summary) in group {
                        if let embedding = embedding {
                            await MainActor.run {
                                var updatedDoc = self.documents[index]
                                updatedDoc.embedding = embedding
                                if let summary = summary {
                                    updatedDoc.summary = summary
                                }
                                self.documents[index] = updatedDoc
                            }
                        }
                    }
                }
                
                // Small delay between batches to prevent overwhelming the system
                try? await Task.sleep(nanoseconds: 100_000_000) // 0.1 seconds
            }
            
            await MainActor.run {
                isGeneratingEmbeddings = false
                updateSortedResults()
            }
        }
        
        func performSearch() async {
            // Clear results if search is empty
            guard !searchQuery.isEmpty else {
                await MainActor.run {
                    self.searchEmbedding = nil
                    self.sortedResults = self.documents
                }
                return
            }
            
            // Skip embedding generation if query is too short
            if searchQuery.count < 3 {
                await MainActor.run {
                    self.searchEmbedding = nil
                    self.sortedResults = self.documents.filter {
                        $0.name.lowercased().contains(self.searchQuery.lowercased()) ||
                        $0.text.lowercased().contains(self.searchQuery.lowercased()) ||
                        ($0.summary?.lowercased().contains(self.searchQuery.lowercased()) ?? false)
                    }
                }
                return
            }
            
            do {
                if !embeddingService.isModelLoaded {
                    try await Embedding.MLXService.shared.loadEmbeddingModel()
                }
                
                // First, enhance the search query using the text generation model
                let enhancedQuery = try await embeddingService.enhanceSearchQuery(self.searchQuery)
                print("Enhanced search query: \(enhancedQuery)")
                
                // Generate embeddings for the enhanced query
                let embedding = try await embeddingService.generateEmbedding(for: enhancedQuery)
                
                await MainActor.run {
                    self.searchEmbedding = embedding
                    self.updateSortedResults()
                }
            } catch {
                print("Error generating search embedding: \(error)")
                
                // Fall back to simple text search on error
                await MainActor.run {
                    self.searchEmbedding = nil
                    self.sortedResults = self.documents.filter {
                        $0.name.lowercased().contains(self.searchQuery.lowercased()) ||
                        $0.text.lowercased().contains(self.searchQuery.lowercased()) ||
                        ($0.summary?.lowercased().contains(self.searchQuery.lowercased()) ?? false)
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
