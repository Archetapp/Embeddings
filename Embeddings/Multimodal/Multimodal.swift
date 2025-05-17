import Foundation

enum Multimodal {
    // This is just an enum file, used as a namespace
    // All multimodal-related functionality will be organized using this namespace
    
    enum ServiceError: Error {
        case modelNotLoaded
        case processingFailed
        case imageLoadingFailed
        case audioLoadingFailed
        case audioExtractionFailed
        case unsupportedFileFormat
        case fileNotFound
        case openAIError(String)
    }
    
    enum AnalysisMode {
        case local  // Uses MLX models
        case openai // Uses OpenAI APIs
    }
} 
