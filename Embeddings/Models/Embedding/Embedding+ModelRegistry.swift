import Foundation
import MLX

extension Embedding {
    enum ModelRegistry {
        // Text embedding models - these are placeholder configurations
        // In a real implementation, these would reference actual MLX model files
        static let allMiniLM_L6_v2_4bit = ModelConfiguration(
            id: "all-MiniLM-L6-v2-4bit",
            modelPath: "~/Models/all-MiniLM-L6-v2-4bit",
            tokenizerType: "sentencepiece",
            embeddingDimension: 384
        )
        
        static let bgeSmall_4bit = ModelConfiguration(
            id: "bge-small-en-v1.5-4bit",
            modelPath: "~/Models/bge-small-en-v1.5-4bit",
            tokenizerType: "sentencepiece",
            embeddingDimension: 384
        )
        
        static let e5_mistral_7B_instruct = ModelConfiguration(
            id: "e5-mistral-7b-instruct",
            modelPath: "~/Models/e5-mistral-7b-instruct",
            tokenizerType: "sentencepiece",
            embeddingDimension: 4096
        )
        
        // For now, we'll use general language models for embeddings
        static let llama3_2_1B_4bit = ModelConfiguration(
            id: "llama-3.2-1b-instruct-4bit",
            modelPath: "~/Models/llama-3.2-1b-instruct-4bit",
            tokenizerType: "sentencepiece",
            embeddingDimension: 2048
        )
    }
    
    struct ModelConfiguration {
        let id: String
        let modelPath: String
        let tokenizerType: String
        let embeddingDimension: Int
    }
}
