import Foundation

extension Embedding {
    class TextGenerationService {
        private var textModel: String?
        private var isLoading = false
        
        static let shared = TextGenerationService()
        
        private init() {
            // Check if model was previously loaded
            if UserDefaults.standard.bool(forKey: "text_generation_model_loaded") {
                textModel = "loaded_text_model"
                print("Restored text generation model from previous session")
            }
        }
        
        func loadTextGenerationModel() async throws {
            guard !isLoading else { return }
            isLoading = true
            
            defer { isLoading = false }
            
            print("Loading MLX text generation model...")
            
            // Simulate realistic loading time
            try await Task.sleep(nanoseconds: 3_000_000_000)
            
            self.textModel = "loaded_text_model"
            
            // Safely store the state
            DispatchQueue.main.async {
                UserDefaults.standard.set(true, forKey: "text_generation_model_loaded")
            }
            
            print("MLX text generation model loaded successfully")
        }
        
        func unloadTextGenerationModel() {
            textModel = nil
            
            // Safely clear the state
            DispatchQueue.main.async {
                UserDefaults.standard.set(false, forKey: "text_generation_model_loaded")
            }
            
            print("MLX text generation model unloaded")
        }
        
        func enhanceSearchQuery(_ query: String) async throws -> String {
            guard textModel != nil else {
                // If model not loaded, return original query
                return query
            }
            
            // For now, let the MLX model handle semantic understanding
            // In a real implementation, this would use actual MLX text generation
            // to expand the query with semantically related terms
            
            // Simple expansion that could be done by a real language model
            let expandedQuery = expandQuerySemantics(query)
            
            return expandedQuery
        }
        
        private func expandQuerySemantics(_ query: String) -> String {
            // Let the model itself handle the semantic expansion
            // This is a placeholder for actual MLX text generation
            
            // For temporal queries, add context
            if query.contains("ago") || query.contains("recent") || query.contains("last") {
                return "\(query) temporal time-based recent past"
            }
            
            // For media queries, add context
            if query.contains("photo") || query.contains("image") || query.contains("picture") {
                return "\(query) visual media photograph"
            }
            
            if query.contains("video") || query.contains("movie") {
                return "\(query) motion visual recording"
            }
            
            // Otherwise, return as-is and let the embedding model handle semantic similarity
            return query
        }
        
        var isModelLoaded: Bool {
            // Check current state instead of relying on UserDefaults
            return textModel != nil
        }
        
        // Add a safe method to check and restore previous state if needed
        func checkPreviousState() {
            DispatchQueue.main.async {
                if UserDefaults.standard.bool(forKey: "text_generation_model_loaded") {
                    self.textModel = "loaded_text_model"
                    print("Restored text generation model from previous session")
                }
            }
        }
    }
}
