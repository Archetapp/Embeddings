import SwiftUI

extension AppView {
    struct SettingsView: View {
        @Environment(\.dismiss) var dismiss
        
        @State private var preferLocalModels = true
        @State private var embeddingModelStatus = "Not loaded"
        @State private var textGenerationModelStatus = "Not loaded"
        @State private var visionModelStatus = "Not loaded"
        @State private var audioModelStatus = "Not loaded"
        @State private var isLoadingEmbedding = false
        @State private var isLoadingTextGeneration = false
        @State private var isLoadingVision = false
        @State private var isLoadingAudio = false
        @State private var selectedEmbeddingModel = "e5_mistral_7B_instruct"
        @State private var selectedTextGenerationModel = "gemma_2_2b_it_4bit"
        @State private var selectedVisionModel = "llama3_2_3B_vision"
        @State private var selectedAudioModel = "llama3_2_1B_audio"
        
        @State private var isIndexingFolder = false
        @State private var indexingProgress = ""
        @State private var selectedFolderPath = ""
        @State private var showingFolderPicker = false
        @State private var includeSubfolders = true
        @State private var maxDepth = 3
        @State private var documentsProcessed = 0
        @State private var totalDocuments = 0
        @State private var indexingTask: Task<Void, Never>?
        @State private var showingPermissionAlert = false
        
        let embeddingModels = [
            ("e5_mistral_7B_instruct", "E5-Mistral 7B Instruct", "High-quality embeddings (recommended)"),
            ("allMiniLM_L6_v2", "all-MiniLM-L6-v2", "Optimized for embeddings"),
            ("bgeSmall_4bit", "BGE Small (4-bit)", "Fast, lightweight embeddings"),
            ("llama3_2_1B_4bit", "Llama 3.2 1B (4-bit)", "Small, fast fallback")
        ]
        
        let textGenerationModels = [
            ("gemma_2_2b_it_4bit", "Gemma-2-2B-IT-4bit", "Smaller Google model (recommended)"),
            ("gemma_2_9b_it_4bit", "Gemma-2-9B-IT-4bit", "Larger Google model"),
            ("deepseek_r1_4bit", "DeepSeek-R1 4-bit", "Advanced reasoning model"),
            ("llama3_2_3B_text", "Llama 3.2 3B Text", "Query enhancement & generation"),
            ("llama3_2_1B_4bit", "Llama 3.2 1B (4-bit)", "Smaller, faster generation")
        ]
        
        let visionModels = [
            ("llama3_2_3B_vision", "Llama 3.2 3B Vision", "Good balance of speed/quality"),
            ("qwen2_vl_2B", "Qwen2-VL 2B", "Specialized vision model")
        ]
        
        let audioModels = [
            ("llama3_2_1B_audio", "Llama 3.2 1B Audio", "General purpose audio"),
            ("whisper_small", "Whisper Small", "Dedicated transcription model")
        ]
        
        var body: some View {
            VStack(spacing: 0) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("MLX Local Models")
                            .font(.title2)
                            .fontWeight(.bold)
                        Text("On-device AI processing with Apple's MLX framework")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    Button("Done") {
                        dismiss()
                    }
                    .buttonStyle(.borderedProminent)
                }
                .padding()
                .background(Material.bar)
                
                ScrollView {
                    VStack(spacing: 20) {
                        
                        GroupBox("Folder Indexing") {
                            VStack(spacing: 16) {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Full Disk Access Required")
                                            .fontWeight(.medium)
                                        Text("To index all folders, grant Full Disk Access in System Preferences > Privacy & Security")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                    Spacer()
                                    Button("Open Settings") {
                                        openSystemPreferences()
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 6)
                                .background(Color.orange.opacity(0.1))
                                .cornerRadius(8)
                                
                                HStack {
                                    Text("Selected Folder:")
                                        .fontWeight(.medium)
                                        .frame(width: 100, alignment: .leading)
                                    
                                    Text(selectedFolderPath.isEmpty ? "No folder selected" : selectedFolderPath)
                                        .foregroundColor(selectedFolderPath.isEmpty ? .secondary : .primary)
                                        .lineLimit(1)
                                        .truncationMode(.middle)
                                    
                                    Spacer()
                                    
                                    Button("Choose Folder") {
                                        showingFolderPicker = true
                                    }
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                                
                                HStack {
                                    Toggle("Include Subfolders", isOn: $includeSubfolders)
                                    
                                    Spacer()
                                    
                                    if includeSubfolders {
                                        HStack {
                                            Text("Max Depth:")
                                            Stepper(value: $maxDepth, in: 1...10) {
                                                Text("\(maxDepth)")
                                                    .frame(width: 20)
                                            }
                                        }
                                    }
                                }
                                
                                if isIndexingFolder {
                                    VStack(spacing: 8) {
                                        HStack {
                                            ProgressView()
                                                .scaleEffect(0.8)
                                            Text(indexingProgress)
                                                .font(.subheadline)
                                        }
                                        
                                        if totalDocuments > 0 {
                                            ProgressView(value: Double(documentsProcessed), total: Double(totalDocuments))
                                                .progressViewStyle(LinearProgressViewStyle())
                                            
                                            Text("\(documentsProcessed) of \(totalDocuments) documents processed")
                                                .font(.caption)
                                                .foregroundColor(.secondary)
                                        }
                                    }
                                }
                                
                                HStack {
                                    Button(isIndexingFolder ? "Stop Indexing" : "Index Folder") {
                                        if isIndexingFolder {
                                            stopIndexing()
                                        } else {
                                            indexSelectedFolder()
                                        }
                                    }
                                    .disabled(selectedFolderPath.isEmpty)
                                    .buttonStyle(.borderedProminent)
                                    .controlSize(.small)
                                    
                                    Button("Index Entire Computer") {
                                        indexEntireComputer()
                                    }
                                    .disabled(isIndexingFolder)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                        }

                        GroupBox("Text Embedding Models") {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Model:")
                                        .fontWeight(.medium)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Picker("Embedding Model", selection: $selectedEmbeddingModel) {
                                        ForEach(embeddingModels, id: \.0) { model in
                                            Text(model.1).tag(model.0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(embeddingModelStatus == "Loaded" ? .green :
                                                 embeddingModelStatus == "Loading..." ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                        
                                        Text("Status: \(embeddingModelStatus)")
                                            .font(.subheadline)
                                        
                                        if isLoadingEmbedding {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .progressViewStyle(CircularProgressViewStyle())
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(embeddingModelStatus == "Loaded" ? "Reload" : "Load Model") {
                                        loadEmbeddingModel()
                                    }
                                    .disabled(isLoadingEmbedding)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                        }
                        
                        GroupBox("Text Generation Models") {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Model:")
                                        .fontWeight(.medium)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Picker("Text Generation Model", selection: $selectedTextGenerationModel) {
                                        ForEach(textGenerationModels, id: \.0) { model in
                                            Text(model.1).tag(model.0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(textGenerationModelStatus == "Loaded" ? .green :
                                                 textGenerationModelStatus == "Loading..." ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                        
                                        Text("Status: \(textGenerationModelStatus)")
                                            .font(.subheadline)
                                        
                                        if isLoadingTextGeneration {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .progressViewStyle(CircularProgressViewStyle())
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(textGenerationModelStatus == "Loaded" ? "Reload" : "Load Model") {
                                        loadTextGenerationModel()
                                    }
                                    .disabled(isLoadingTextGeneration)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                        }
                        
                        GroupBox("Vision Models") {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Model:")
                                        .fontWeight(.medium)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Picker("Vision Model", selection: $selectedVisionModel) {
                                        ForEach(visionModels, id: \.0) { model in
                                            Text(model.1).tag(model.0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(visionModelStatus == "Loaded" ? .green :
                                                 visionModelStatus == "Loading..." ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                        
                                        Text("Status: \(visionModelStatus)")
                                            .font(.subheadline)
                                        
                                        if isLoadingVision {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .progressViewStyle(CircularProgressViewStyle())
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(visionModelStatus == "Loaded" ? "Reload" : "Load Model") {
                                        loadVisionModel()
                                    }
                                    .disabled(isLoadingVision)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                        }
                        
                        GroupBox("Audio Models") {
                            VStack(spacing: 16) {
                                HStack {
                                    Text("Model:")
                                        .fontWeight(.medium)
                                        .frame(width: 60, alignment: .leading)
                                    
                                    Picker("Audio Model", selection: $selectedAudioModel) {
                                        ForEach(audioModels, id: \.0) { model in
                                            Text(model.1).tag(model.0)
                                        }
                                    }
                                    .pickerStyle(.menu)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                
                                Divider()
                                
                                HStack {
                                    HStack(spacing: 8) {
                                        Circle()
                                            .fill(audioModelStatus == "Loaded" ? .green :
                                                 audioModelStatus == "Loading..." ? .yellow : .gray)
                                            .frame(width: 8, height: 8)
                                        
                                        Text("Status: \(audioModelStatus)")
                                            .font(.subheadline)
                                        
                                        if isLoadingAudio {
                                            ProgressView()
                                                .scaleEffect(0.6)
                                                .progressViewStyle(CircularProgressViewStyle())
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    Button(audioModelStatus == "Loaded" ? "Reload" : "Load Model") {
                                        loadAudioModel()
                                    }
                                    .disabled(isLoadingAudio)
                                    .buttonStyle(.bordered)
                                    .controlSize(.small)
                                }
                            }
                            .padding()
                        }
                        
                        HStack {
                            Button("Open Storage Folder") {
                                openStorageFolder()
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                            
                            Spacer()
                        }
                        
                        HStack(spacing: 12) {
                            Button("Load All Models") {
                                loadAllModels()
                            }
                            .disabled(isLoadingEmbedding || isLoadingTextGeneration || isLoadingVision || isLoadingAudio)
                            .buttonStyle(.borderedProminent)
                            
                            Button("Clear All Models") {
                                clearAllModels()
                            }
                            .disabled(isLoadingEmbedding || isLoadingTextGeneration || isLoadingVision || isLoadingAudio)
                            .buttonStyle(.bordered)
                            .foregroundColor(.red)
                        }
                        
                        GroupBox("About MLX Models") {
                            VStack(alignment: .leading, spacing: 12) {
                                HStack(spacing: 8) {
                                    Image(systemName: "lock.shield.fill")
                                        .foregroundColor(.green)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Privacy First")
                                            .fontWeight(.medium)
                                        Text("All processing happens on your device. No data is sent to external servers.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "wifi.slash")
                                        .foregroundColor(.blue)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Offline Capable")
                                            .fontWeight(.medium)
                                        Text("Works without internet connection once models are downloaded.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                
                                HStack(spacing: 8) {
                                    Image(systemName: "cpu.fill")
                                        .foregroundColor(.orange)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text("Apple Silicon Optimized")
                                            .fontWeight(.medium)
                                        Text("Optimized for M-series chips with hardware acceleration.")
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                            }
                            .padding()
                            .frame(maxWidth: .infinity)
                        }
                    }
                    .padding()
                }
            }
            .frame(width: 700, height: 800)
            .fileImporter(
                isPresented: $showingFolderPicker,
                allowedContentTypes: [.folder],
                allowsMultipleSelection: false
            ) { result in
                do {
                    let urls = try result.get()
                    if let folderURL = urls.first {
                        selectedFolderPath = folderURL.path
                    }
                } catch {
                    print("Error selecting folder: \(error)")
                }
            }
            .onAppear {
                checkModelStatus()
                // Set default folder to user's home directory if not already set
                if selectedFolderPath.isEmpty {
                    selectedFolderPath = FileManager.default.homeDirectoryForCurrentUser.path
                }
            }
        }
        
        private func indexEntireComputer() {
            selectedFolderPath = FileManager.default.homeDirectoryForCurrentUser.path
            indexSelectedFolder()
        }
        
        private func openSystemPreferences() {
            let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!
            NSWorkspace.shared.open(url)
        }
        
        private func indexSelectedFolder() {
            guard !selectedFolderPath.isEmpty else { return }
            
            let folderURL = URL(fileURLWithPath: selectedFolderPath)
            
            isIndexingFolder = true
            indexingProgress = "Scanning folder..."
            documentsProcessed = 0
            totalDocuments = 0
            
            indexingTask = Task {
                do {
                    let allFiles = try await scanFolderWithPermissions(url: folderURL, depth: 0, maxDepth: includeSubfolders ? maxDepth : 1)
                    
                    guard !Task.isCancelled else { return }
                    
                    await MainActor.run {
                        self.totalDocuments = allFiles.count
                        self.indexingProgress = "Processing documents..."
                    }
                    
                    await processDocuments(files: allFiles)
                    
                    await MainActor.run {
                        self.isIndexingFolder = false
                        self.indexingProgress = "Completed - \(self.documentsProcessed) documents processed"
                    }
                } catch {
                    print("Error indexing folder: \(error)")
                    await MainActor.run {
                        self.isIndexingFolder = false
                        self.indexingProgress = "Error: \(error.localizedDescription)"
                    }
                }
            }
        }
        
        private func stopIndexing() {
            indexingTask?.cancel()
            indexingTask = nil
            isIndexingFolder = false
            indexingProgress = "Stopped"
        }
        
        private func scanFolderWithPermissions(url: URL, depth: Int, maxDepth: Int) async throws -> [URL] {
            guard !Task.isCancelled, depth < maxDepth else { return [] }
            
            var allFiles: [URL] = []
            let fileManager = FileManager.default
            
            let shouldAccessSecurityScoped = url.startAccessingSecurityScopedResource()
            defer {
                if shouldAccessSecurityScoped {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: url,
                    includingPropertiesForKeys: [.isDirectoryKey, .isReadableKey],
                    options: [.skipsHiddenFiles, .skipsPackageDescendants]
                )
                
                for item in contents {
                    guard !Task.isCancelled else { break }
                    
                    do {
                        let resourceValues = try item.resourceValues(forKeys: [.isDirectoryKey, .isReadableKey])
                        
                        guard resourceValues.isReadable == true else { continue }
                        
                        if resourceValues.isDirectory == true {
                            if includeSubfolders && depth + 1 < maxDepth {
                                do {
                                    let subFiles = try await scanFolderWithPermissions(url: item, depth: depth + 1, maxDepth: maxDepth)
                                    allFiles.append(contentsOf: subFiles)
                                } catch {
                                    print("Skipping folder \(item.lastPathComponent): Access denied")
                                    continue
                                }
                            }
                        } else {
                            let fileType = Document.Handler.getFileType(for: item)
                            if fileType != .unknown {
                                allFiles.append(item)
                            }
                        }
                    } catch {
                        print("Skipping item \(item.lastPathComponent): \(error.localizedDescription)")
                        continue
                    }
                }
            } catch {
                if selectedFolderPath == "/" {
                    print("Skipping protected folder: \(url.lastPathComponent)")
                    return []
                } else {
                    throw error
                }
            }
            
            return allFiles
        }
        
        private func processDocuments(files: [URL]) async {
            let batchSize = 8 // Increase batch size for better concurrency
            
            for i in stride(from: 0, to: files.count, by: batchSize) {
                guard !Task.isCancelled else { break }
                
                let endIndex = min(i + batchSize, files.count)
                let batch = Array(files[i..<endIndex])
                
                // Process batch concurrently
                await withTaskGroup(of: Document.Model?.self) { group in
                    for fileURL in batch {
                        guard !Task.isCancelled else { break }
                        
                        group.addTask {
                            guard !Task.isCancelled else { return nil }
                            
                            do {
                                // Create security scoped bookmark
                                var bookmark: Data?
                                let shouldStopAccessing = fileURL.startAccessingSecurityScopedResource()
                                defer {
                                    if shouldStopAccessing {
                                        fileURL.stopAccessingSecurityScopedResource()
                                    }
                                }
                                
                                // Try to create bookmark while we have access
                                do {
                                    bookmark = try fileURL.bookmarkData(
                                        options: [.securityScopeAllowOnlyReadAccess],
                                        includingResourceValuesForKeys: nil,
                                        relativeTo: nil
                                    )
                                } catch {
                                    // If security scoped bookmark fails, try minimal bookmark
                                    do {
                                        bookmark = try fileURL.bookmarkData(
                                            options: .minimalBookmark,
                                            includingResourceValuesForKeys: nil,
                                            relativeTo: nil
                                        )
                                    } catch {
                                        // Try app-scoped bookmark as final fallback
                                        do {
                                            bookmark = try fileURL.bookmarkData(
                                                options: [],
                                                includingResourceValuesForKeys: nil,
                                                relativeTo: nil
                                            )
                                        } catch {
                                            print("All bookmark creation methods failed for \(fileURL.lastPathComponent): \(error)")
                                            // Continue without bookmark
                                        }
                                    }
                                }
                                
                                let text = try await Document.Handler.extractText(from: fileURL)
                                let metadata = try await Document.Handler.extractMetadata(from: fileURL)
                                let fileType = Document.Handler.getFileType(for: fileURL)
                                
                                return Document.Model(
                                    name: fileURL.lastPathComponent,
                                    text: text,
                                    embedding: nil,
                                    url: fileURL,
                                    fileType: fileType,
                                    thumbnailURL: nil,
                                    securityScopedBookmark: bookmark,
                                    metadata: metadata
                                )
                                
                            } catch {
                                print("Error processing \(fileURL.lastPathComponent): \(error)")
                                return nil
                            }
                        }
                    }
                    
                    // Collect results and add documents
                    var documentsToAdd: [Document.Model] = []
                    for await document in group {
                        if let document = document {
                            documentsToAdd.append(document)
                        }
                        
                        await MainActor.run {
                            self.documentsProcessed += 1
                        }
                    }
                    
                    // Add all documents from this batch at once
                    await MainActor.run {
                        for document in documentsToAdd {
                            NotificationCenter.default.post(name: NSNotification.Name("AddDocument"), object: document)
                        }
                    }
                }
                
                guard !Task.isCancelled else { break }
                // Shorter delay between batches since we're processing more concurrently
                try? await Task.sleep(nanoseconds: 50_000_000) // 0.05 seconds
            }
        }
        
        private func updateModelPreference(_ prefer: Bool) {
            Embedding.Service().setPreferLocalModels(prefer)
            Multimodal.Service.shared.setAnalysisMode(prefer ? .local : .local)
        }
        
        private func loadEmbeddingModel() {
            isLoadingEmbedding = true
            embeddingModelStatus = "Loading..."
            
            Task {
                do {
                    try await Embedding.MLXService.shared.loadEmbeddingModel()
                    
                    await MainActor.run {
                        self.embeddingModelStatus = "Loaded"
                        self.isLoadingEmbedding = false
                    }
                } catch {
                    print("Failed to load embedding model: \(error)")
                    await MainActor.run {
                        self.embeddingModelStatus = "Failed"
                        self.isLoadingEmbedding = false
                    }
                }
            }
        }
        
        private func loadTextGenerationModel() {
            isLoadingTextGeneration = true
            textGenerationModelStatus = "Loading..."
            
            Task {
                do {
                    try await Embedding.TextGenerationService.shared.loadTextGenerationModel()
                    
                    await MainActor.run {
                        self.textGenerationModelStatus = "Loaded"
                        self.isLoadingTextGeneration = false
                    }
                } catch {
                    print("Failed to load text generation model: \(error)")
                    await MainActor.run {
                        self.textGenerationModelStatus = "Failed: \(error.localizedDescription)"
                        self.isLoadingTextGeneration = false
                    }
                }
            }
        }
        
        private func loadVisionModel() {
            isLoadingVision = true
            visionModelStatus = "Loading..."
            
            Task {
                do {
                    try await Multimodal.MLXService.shared.loadVisionModel()
                    
                    await MainActor.run {
                        self.visionModelStatus = "Loaded"
                        self.isLoadingVision = false
                    }
                } catch {
                    print("Failed to load vision model: \(error)")
                    await MainActor.run {
                        self.visionModelStatus = "Failed"
                        self.isLoadingVision = false
                    }
                }
            }
        }
        
        private func loadAudioModel() {
            isLoadingAudio = true
            audioModelStatus = "Loading..."
            
            Task {
                do {
                    try await Multimodal.MLXService.shared.loadAudioModel()
                    
                    await MainActor.run {
                        self.audioModelStatus = "Loaded"
                        self.isLoadingAudio = false
                    }
                } catch {
                    print("Failed to load audio model: \(error)")
                    await MainActor.run {
                        self.audioModelStatus = "Failed"
                        self.isLoadingAudio = false
                    }
                }
            }
        }
        
        private func loadAllModels() {
            loadEmbeddingModel()
            loadTextGenerationModel()
            loadVisionModel()
            loadAudioModel()
        }
        
        private func clearAllModels() {
            Embedding.MLXService.shared.unloadEmbeddingModel()
            Embedding.TextGenerationService.shared.unloadTextGenerationModel()
            Multimodal.MLXService.shared.unloadAllModels()
            
            embeddingModelStatus = "Not loaded"
            textGenerationModelStatus = "Not loaded"
            visionModelStatus = "Not loaded"
            audioModelStatus = "Not loaded"
        }
        
        private func checkModelStatus() {
            if Embedding.MLXService.shared.isModelLoaded {
                embeddingModelStatus = "Loaded"
            }
            
            if Embedding.TextGenerationService.shared.isModelLoaded {
                textGenerationModelStatus = "Loaded"
            }
            
            if Multimodal.Service.shared.isVisionModelLoaded {
                visionModelStatus = "Loaded"
            }
            
            if Multimodal.Service.shared.isAudioModelLoaded {
                audioModelStatus = "Loaded"
            }
        }
        
        private func openStorageFolder() {
            let fileManager = FileManager.default
            guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
                print("Could not find Application Support directory")
                return
            }
            
            let appURL = appSupportURL.appendingPathComponent(Bundle.main.bundleIdentifier ?? "Embeddings")
            let documentsURL = appURL.appendingPathComponent("Documents")
            
            // Create directory if it doesn't exist
            try? fileManager.createDirectory(at: documentsURL, withIntermediateDirectories: true)
            
            // Open in Finder
            NSWorkspace.shared.open(documentsURL)
        }
    }
}
