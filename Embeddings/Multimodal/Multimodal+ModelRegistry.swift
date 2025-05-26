import Foundation
import MLX

extension Multimodal {
    enum ModelRegistry {
        // Vision models - placeholder configurations
        static let llama3_2_3B_vision = ModelConfiguration(
            id: "llama-3.2-3b-instruct-vision",
            modelPath: "~/Models/llama-3.2-3b-instruct-vision",
            tokenizerType: "sentencepiece",
            modelType: .vision
        )
        
        static let qwen2_vl_2B = ModelConfiguration(
            id: "qwen2-vl-2b-instruct",
            modelPath: "~/Models/qwen2-vl-2b-instruct",
            tokenizerType: "qwen",
            modelType: .vision
        )
        
        // Audio models (Whisper-like)
        static let llama3_2_1B_audio = ModelConfiguration(
            id: "llama-3.2-1b-instruct-audio",
            modelPath: "~/Models/llama-3.2-1b-instruct-audio",
            tokenizerType: "sentencepiece",
            modelType: .audio
        )
        
        static let whisper_small = ModelConfiguration(
            id: "whisper-small-mlx",
            modelPath: "~/Models/whisper-small-mlx",
            tokenizerType: "whisper",
            modelType: .audio
        )
        
        // General text models
        static let llama3_2_3B_text = ModelConfiguration(
            id: "llama-3.2-3b-instruct",
            modelPath: "~/Models/llama-3.2-3b-instruct",
            tokenizerType: "sentencepiece",
            modelType: .text
        )
        
        static let llama3_2_1B_4bit = ModelConfiguration(
            id: "llama-3.2-1b-instruct-4bit",
            modelPath: "~/Models/llama-3.2-1b-instruct-4bit",
            tokenizerType: "sentencepiece",
            modelType: .text
        )
    }
    
    struct ModelConfiguration {
        let id: String
        let modelPath: String
        let tokenizerType: String
        let modelType: ModelType
    }
    
    enum ModelType {
        case vision
        case audio
        case text
    }
}
