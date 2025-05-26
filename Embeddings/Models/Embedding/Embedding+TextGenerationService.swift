import Foundation
import MLX
import MLXLLM
import MLXLMCommon
import MLXRandom

extension Embedding {
    @MainActor
    class TextGenerationService: ObservableObject {
        @Published var output = ""
        @Published var running = false
        
        private var modelContainer: MLXLMCommon.ModelContainer?
        private var isLoading = false
        
        static let shared = TextGenerationService()
        
        private init() {
            checkPreviousState()
        }
        
        func loadTextGenerationModel() async throws {
            guard !isLoading else { return }
            isLoading = true
            
            defer { isLoading = false }
            
            print("DEBUG: Loading Gemma-2-2B-IT-4bit text generation model...")
            
            do {
                let container = try await withError { _ in
                    let configuration = MLXLMCommon.ModelConfiguration(
                        id: "mlx-community/gemma-2-2b-it-4bit"
                    )
                    
                    let container = try await LLMModelFactory.shared.loadContainer(
                        configuration: configuration
                    ) { progress in
                        print("DEBUG: Model download progress: \(progress.fractionCompleted)")
                    }
                    
                    return container
                }
                
                self.modelContainer = container
                
                DispatchQueue.main.async {
                    UserDefaults.standard.set(true, forKey: "text_generation_model_loaded")
                }
                
                print("DEBUG: Gemma-2-2B-IT-4bit model loaded successfully")
            } catch {
                print("DEBUG: Failed to load Gemma model: \(error)")
                throw error
            }
        }
        
        func unloadTextGenerationModel() {
            modelContainer = nil
            
            DispatchQueue.main.async {
                UserDefaults.standard.set(false, forKey: "text_generation_model_loaded")
            }
            
            print("DEBUG: Gemma model unloaded")
        }
        
        func enhanceSearchQuery(_ query: String) async throws -> String {
            print("DEBUG: Enhancing search query: '\(query)'")
            
            guard let container = modelContainer else {
                print("DEBUG: Model not loaded, returning original query")
                return query
            }
            
            print("DEBUG: Model is loaded, processing query enhancement...")
            
            let prompt = "Enhance this search query with related terms: \(query)\nEnhanced:"
            
            do {
                let enhancedQuery = try await generateText(container: container, prompt: prompt, maxTokens: 20)
                print("DEBUG: Query enhanced from '\(query)' to '\(enhancedQuery)'")
                return enhancedQuery.isEmpty ? query : enhancedQuery
            } catch {
                print("DEBUG: Query enhancement failed: \(error)")
                return query
            }
        }
        
        func summarizeDocument(_ text: String) async throws -> String {
            print("DEBUG: Starting document summarization...")
            print("DEBUG: Document text length: \(text.count) characters")
            print("DEBUG: Model loaded: \(isModelLoaded)")
            
            guard let container = modelContainer else {
                print("DEBUG: Model not loaded, cannot generate summary")
                return "Model couldn't generate summary - model not loaded"
            }
            
            print("DEBUG: Model is loaded, attempting to generate summary...")
            
            let truncatedText = text.count > 1500 ? String(text.prefix(1500)) + "..." : text
            
            let prompt = "Summarize this document briefly:\n\n\(truncatedText)\n\nSummary:"
            
            do {
                let summary = try await generateText(container: container, prompt: prompt, maxTokens: 50)
                let cleanedSummary = summary.trimmingCharacters(in: .whitespacesAndNewlines)
                print("DEBUG: Generated summary: '\(cleanedSummary)'")
                return cleanedSummary.isEmpty ? "Model couldn't generate summary" : cleanedSummary
            } catch {
                print("DEBUG: Text generation failed: \(error)")
                return "Model couldn't generate summary"
            }
        }
        
        private func generateText(container: MLXLMCommon.ModelContainer, prompt: String, maxTokens: Int = 100) async throws -> String {
            print("DEBUG: Generating text with prompt length: \(prompt.count)")
            
            return try await container.perform { (context: MLXLMCommon.ModelContext) in
                return try await withError { _ in
                    let tokens = try context.tokenizer.encode(text: prompt)
                    let lmInput = LMInput(tokens: MLXArray(tokens))
                    
                    let parameters = GenerateParameters(
                        temperature: 0.3,
                        topP: 0.8,
                        repetitionPenalty: 1.2
                    )
                    
                    var generatedText = ""
                    var tokenCount = 0
                    var previousChunk = ""
                    
                    let result = try await MLXLMCommon.generate(
                        input: lmInput,
                        parameters: parameters,
                        context: context
                    ) { tokens in
                        let chunk = context.tokenizer.decode(tokens: tokens)
                        
                        // Check for repetition
                        if chunk == previousChunk && !chunk.isEmpty {
                            print("DEBUG: Detected repetition, stopping generation")
                            return .stop
                        }
                        
                        // Check for common stop sequences
                        if chunk.contains("<end_of_turn>") || chunk.contains("</s>") || chunk.contains("<|endoftext|>") {
                            print("DEBUG: Found stop token, ending generation")
                            return .stop
                        }
                        
                        // Stop if we're generating the same phrase repeatedly
                        if generatedText.contains(chunk) && chunk.count > 5 {
                            print("DEBUG: Detected repeated phrase, stopping")
                            return .stop
                        }
                        
                        generatedText += chunk
                        previousChunk = chunk
                        tokenCount += tokens.count
                        
                        if tokenCount >= maxTokens {
                            print("DEBUG: Reached max tokens, stopping")
                            return .stop
                        }
                        
                        return .more
                    }
                    
                    print("DEBUG: Generation completed with \(tokenCount) tokens")
                    
                    // Clean up the output
                    var cleanText = generatedText.trimmingCharacters(in: .whitespacesAndNewlines)
                    
                    // Remove stop tokens
                    let stopTokens = ["<end_of_turn>", "</s>", "<|endoftext|>"]
                    for token in stopTokens {
                        cleanText = cleanText.replacingOccurrences(of: token, with: "")
                    }
                    
                    // Remove excessive repetition
                    cleanText = await removeExcessiveRepetition(cleanText)
                    
                    return cleanText.trimmingCharacters(in: .whitespacesAndNewlines)
                }
            }
        }
        
        private func removeExcessiveRepetition(_ text: String) -> String {
            let words = text.components(separatedBy: .whitespacesAndNewlines)
            var result: [String] = []
            var lastWord = ""
            var repetitionCount = 0
            
            for word in words {
                if word == lastWord {
                    repetitionCount += 1
                    if repetitionCount < 2 { // Allow up to 1 repetition
                        result.append(word)
                    }
                } else {
                    repetitionCount = 0
                    result.append(word)
                    lastWord = word
                }
            }
            
            return result.joined(separator: " ")
        }
        
        var isModelLoaded: Bool {
            return modelContainer != nil
        }
        
        func checkPreviousState() {
            let wasLoaded = UserDefaults.standard.bool(forKey: "text_generation_model_loaded")
            if wasLoaded {
                print("DEBUG: Previous model state found, will reload on first use")
            } else {
                print("DEBUG: No previous model state found")
            }
        }
        
        func getModelInfo() -> String? {
            guard let _ = modelContainer else {
                print("DEBUG: getModelInfo called but model not loaded")
                return nil
            }
            
            let info = """
            Model: Gemma-2-2B-IT-4bit
            Loaded: \(isModelLoaded)
            """
            
            print("DEBUG: Model info: \(info)")
            return info
        }
    }
}

extension Embedding.TextGenerationService {
    func summarizeDocumentText(_ documentText: String) async throws -> String {
        print("DEBUG: summarizeDocumentText called with \(documentText.count) characters")
        return try await summarizeDocument(documentText)
    }
}
