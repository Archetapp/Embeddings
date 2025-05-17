import Foundation

// Response structs for Codable decoding
struct EmbeddingResponse: Codable {
    let data: [EmbeddingData]
}

struct EmbeddingData: Codable {
    let embedding: [Float]
    let index: Int
    let object: String
}

enum Embedding {
    // This is just an enum file, used as a namespace
    // All embedding-related functionality will be organized using this namespace
} 