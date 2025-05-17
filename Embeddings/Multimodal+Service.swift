import Foundation
import AppKit
import Vision
import AVFoundation

extension Multimodal {
    class Service {
        static let shared = Service()
        
        private let openAIService = Embedding.Service()
        private var mlxModel: Any? = nil
        private var analysisMode: AnalysisMode = .openai
        
        private init() {
            // Try to load local MLX model if available
            loadLocalModel()
        }
        
        private func loadLocalModel() {
            // Check if we have MLX models installed in standard locations
            let modelPath = "/Users/Shared/MLX/llava-1.5-7b-mlx"
            
            if FileManager.default.fileExists(atPath: modelPath) {
                // In a real app, we would load the MLX model here
                // Since MLX API isn't directly accessible from Swift without wrappers,
                // this is a placeholder for future implementation
                
                print("MLX model found at \(modelPath)")
                analysisMode = .local
            } else {
                print("No local MLX models found, will use OpenAI")
                analysisMode = .openai
            }
        }
        
        func setAPIKey(_ key: String) {
            openAIService.setAPIKey(key)
        }
        
        func analyzeImage(url: URL) async throws -> String {
            switch analysisMode {
                case .local:
                    return try await analyzeImageWithMLX(url: url)
                case .openai:
                    return try await analyzeImageWithOpenAI(url: url)
            }
        }
        
        func analyzeImage(image: NSImage) async throws -> String {
            switch analysisMode {
                case .local:
                    return try await analyzeImageWithMLX(image: image)
                case .openai:
                    return try await analyzeImageWithOpenAI(image: image)
            }
        }
        
        func analyzeAudio(url: URL) async throws -> String {
            switch analysisMode {
                case .local:
                    return try await analyzeAudioWithMLX(url: url)
                case .openai:
                    return try await analyzeAudioWithOpenAI(url: url)
            }
        }
        
        func analyzeVideo(url: URL) async throws -> (imageDescription: String, audioTranscription: String) {
            // Extract a frame from the video for image analysis
            let image = try await extractFrameFromVideo(url: url)
            
            // Run image and audio analysis in parallel using async tasks
            async let imageAnalysis = analyzeImage(image: image)
            async let audioAnalysis = analyzeAudio(url: url)
            
            // Wait for both to complete and return results
            return try await (imageAnalysis, audioAnalysis)
        }
        
        // MARK: - MLX Implementations
        
        private func analyzeImageWithMLX(url: URL) async throws -> String {
            guard let image = NSImage(contentsOf: url) else {
                throw ServiceError.imageLoadingFailed
            }
            
            return try await analyzeImageWithMLX(image: image)
        }
        
        private func analyzeImageWithMLX(image: NSImage) async throws -> String {
            // This is where we would use Python bindings or a local server to call MLX models
            // For now, we'll just return a placeholder
            
            // In a real implementation, we would:
            // 1. Convert the NSImage to format expected by MLX
            // 2. Call the model with the image data
            // 3. Process the response
            
            return "MLX image analysis would describe the image here"
        }
        
        private func analyzeAudioWithMLX(url: URL) async throws -> String {
            // For now, just return a placeholder
            // In a full implementation, we would process audio through MLX models
            
            return "MLX audio analysis would transcribe and describe the audio here"
        }
        
        // MARK: - OpenAI Implementations
        
        private func analyzeImageWithOpenAI(url: URL) async throws -> String {
            guard let image = NSImage(contentsOf: url) else {
                throw ServiceError.imageLoadingFailed
            }
            
            return try await analyzeImageWithOpenAI(image: image)
        }
        
        private func analyzeImageWithOpenAI(image: NSImage) async throws -> String {
            // Convert NSImage to base64 string
            guard let base64Image = convertImageToBase64(image) else {
                throw ServiceError.imageLoadingFailed
            }
            
            return try await openAIService.generateImageDescription(base64Image: base64Image)
        }
        
        private func analyzeAudioWithOpenAI(url: URL) async throws -> String {
            // Check if file exists
            guard FileManager.default.fileExists(atPath: url.path) else {
                throw ServiceError.fileNotFound
            }
            
            // Check if URL is an audio file
            let audioExtensions = ["mp3", "wav", "m4a", "mp4", "mov"]
            guard audioExtensions.contains(url.pathExtension.lowercased()) else {
                throw ServiceError.unsupportedFileFormat
            }
            
            // For audio or video files, extract the audio track if necessary
            var audioURL = url
            if ["mp4", "mov"].contains(url.pathExtension.lowercased()) {
                // Extract audio from video
                audioURL = try await extractAudioFromVideo(url: url)
            }
            
            // Send the audio file to OpenAI's Whisper API
            return try await openAIService.transcribeAudio(url: audioURL)
        }
        
        // MARK: - Helper Methods
        
        private func convertImageToBase64(_ image: NSImage) -> String? {
            guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
                return nil
            }
            
            let bitmapRep = NSBitmapImageRep(cgImage: cgImage)
            guard let data = bitmapRep.representation(using: .jpeg, properties: [.compressionFactor: 0.7]) else {
                return nil
            }
            
            return data.base64EncodedString()
        }
        
        private func extractFrameFromVideo(url: URL) async throws -> NSImage {
            let asset = AVAsset(url: url)
            let imageGenerator = AVAssetImageGenerator(asset: asset)
            imageGenerator.appliesPreferredTrackTransform = true
            
            // Get frame at 1 second or middle of video, whichever is earlier
            let duration = try await asset.load(.duration)
            let time = min(CMTime(seconds: 1, preferredTimescale: 600), CMTime(seconds: duration.seconds / 2, preferredTimescale: 600))
            
            let cgImage = try imageGenerator.copyCGImage(at: time, actualTime: nil)
            return NSImage(cgImage: cgImage, size: .zero)
        }
        
        private func extractAudioFromVideo(url: URL) async throws -> URL {
            let asset = AVAsset(url: url)
            
            // Create a temporary file URL for the extracted audio
            let tempDir = FileManager.default.temporaryDirectory
            let audioFileName = UUID().uuidString + ".m4a"
            let audioURL = tempDir.appendingPathComponent(audioFileName)
            
            // Set up export session
            guard let exportSession = AVAssetExportSession(asset: asset, presetName: AVAssetExportPresetAppleM4A) else {
                throw ServiceError.audioExtractionFailed
            }
            
            exportSession.outputURL = audioURL
            exportSession.outputFileType = .m4a
            exportSession.audioTimePitchAlgorithm = .spectral
            
            // Export audio
            return try await withCheckedThrowingContinuation { continuation in
                exportSession.exportAsynchronously {
                    if exportSession.status == .completed {
                        continuation.resume(returning: audioURL)
                    } else {
                        continuation.resume(throwing: ServiceError.audioExtractionFailed)
                    }
                }
            }
        }
    }
}
