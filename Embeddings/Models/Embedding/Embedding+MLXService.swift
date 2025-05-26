import Foundation
import MLX

extension Embedding {
    class MLXService {
        static let shared = MLXService()
        
        private var embeddingModel: Any?
        private let processingQueue = DispatchQueue(label: "mlx.embedding.processing", qos: .userInitiated, attributes: .concurrent)
        private let serialQueue = DispatchQueue(label: "mlx.embedding.serial", qos: .userInitiated)
        
        var isModelLoaded: Bool {
            return embeddingModel != nil
        }
        
        private init() {}
        
        func loadEmbeddingModel() async throws {
            return try await withCheckedThrowingContinuation { continuation in
                serialQueue.async {
                    do {
                        // Simulate model loading - in reality this would load an actual MLX model
                        print("Loading MLX embedding model...")
                        Thread.sleep(forTimeInterval: 1.0) // Simulate loading time
                        self.embeddingModel = "MockEmbeddingModel"
                        print("MLX embedding model loaded successfully")
                        continuation.resume()
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        func generateEmbedding(for text: String) async throws -> [Float] {
            guard isModelLoaded else {
                throw NSError(domain: "MLXService", code: 1, userInfo: [NSLocalizedDescriptionKey: "Model not loaded"])
            }
            
            // Use concurrent queue for processing multiple embeddings simultaneously
            return try await withCheckedThrowingContinuation { continuation in
                processingQueue.async {
                    do {
                        // Simulate embedding generation
                        let embedding = self.generateMockEmbedding(for: text)
                        continuation.resume(returning: embedding)
                    } catch {
                        continuation.resume(throwing: error)
                    }
                }
            }
        }
        
        private func generateMockEmbedding(for text: String) -> [Float] {
            // Generate a consistent but pseudo-random embedding based on text content
            let hash = text.hash
            var embedding: [Float] = []
            
            // Generate 384-dimensional embedding (common for sentence transformers)
            for i in 0..<384 {
                let seed = hash &+ i
                let normalized = Float(seed % 10000) / 10000.0 - 0.5 // Range: -0.5 to 0.5
                embedding.append(normalized)
            }
            
            // Normalize the embedding vector
            let magnitude = sqrt(embedding.reduce(0) { $0 + $1 * $1 })
            if magnitude > 0 {
                embedding = embedding.map { $0 / magnitude }
            }
            
            return embedding
        }
        
        func cosineSimilarity(between embedding1: [Float], and embedding2: [Float]) -> Float {
            guard embedding1.count == embedding2.count else { return 0 }
            
            var dotProduct: Float = 0
            var magnitude1: Float = 0
            var magnitude2: Float = 0
            
            for i in 0..<embedding1.count {
                dotProduct += embedding1[i] * embedding2[i]
                magnitude1 += embedding1[i] * embedding1[i]
                magnitude2 += embedding2[i] * embedding2[i]
            }
            
            magnitude1 = sqrt(magnitude1)
            magnitude2 = sqrt(magnitude2)
            
            guard magnitude1 > 0 && magnitude2 > 0 else { return 0 }
            
            return dotProduct / (magnitude1 * magnitude2)
        }
        
        func unloadEmbeddingModel() {
            serialQueue.sync {
                embeddingModel = nil
                print("MLX embedding model unloaded")
            }
        }
    }
}
