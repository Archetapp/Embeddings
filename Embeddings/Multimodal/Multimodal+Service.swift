import Foundation
import AppKit
import Vision
import AVFoundation

extension Multimodal {
    class Service {
        static let shared = Service()
        
        private let mlxService = MLXService.shared
        private var analysisMode: AnalysisMode = .local
        
        private init() {
            // Don't initialize models in init - do it lazily when needed
        }
        
        private func initializeMLXModels() async throws {
            do {
                try await mlxService.loadVisionModel()
                try await mlxService.loadAudioModel()
                analysisMode = .local
                print("MLX models loaded successfully")
            } catch {
                print("Failed to load MLX models: \(error)")
                throw error
            }
        }
        
        func setAnalysisMode(_ mode: AnalysisMode) {
            analysisMode = mode
        }
        
        func analyzeImage(url: URL) async throws -> String {
            guard let image = NSImage(contentsOf: url) else {
                throw ServiceError.imageLoadingFailed
            }
            
            return try await analyzeImage(image: image)
        }
        
        func analyzeImage(image: NSImage) async throws -> String {
            guard analysisMode == .local else {
                throw ServiceError.processingFailed
            }
            
            return try await mlxService.analyzeImage(image)
        }
        
        func analyzeAudio(url: URL) async throws -> String {
            guard analysisMode == .local else {
                throw ServiceError.processingFailed
            }
            
            return try await mlxService.transcribeAudio(url: url)
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
        
        var isVisionModelLoaded: Bool {
            return mlxService.isVisionModelLoaded
        }
        
        var isAudioModelLoaded: Bool {
            return mlxService.isAudioModelLoaded
        }
        
        // MARK: - Helper Methods
        
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
    }
}
