import Foundation

extension Embedding {
    class Service {
        private let mlxService = MLXService.shared
        private let textGenerationService = TextGenerationService.shared
        private var preferLocalModels = true
        
        func setPreferLocalModels(_ prefer: Bool) {
            self.preferLocalModels = prefer
        }
        
        func initializeMLXModels() async throws {
            do {
                try await mlxService.loadEmbeddingModel()
                print("Embedding model loaded")
            } catch {
                print("Failed to load embedding model: \(error)")
            }
            
            do {
                try await textGenerationService.loadTextGenerationModel()
                print("Text generation model loaded")
            } catch {
                print("Failed to load text generation model: \(error)")
            }
        }
        
        func generateEmbedding(for text: String) async throws -> [Float] {
            return try await mlxService.generateEmbedding(for: text)
        }
        
        func enhanceSearchQuery(_ query: String) async throws -> String {
            return try await textGenerationService.enhanceSearchQuery(query)
        }
        
        func cosineSimilarity(between embedding1: [Float], and embedding2: [Float]) -> Float {
            return mlxService.cosineSimilarity(between: embedding1, and: embedding2)
        }
        
        var isModelLoaded: Bool {
            return mlxService.isModelLoaded && textGenerationService.isModelLoaded
        }
    }
}
