import Foundation

extension Embedding {
    class Service {
        private var apiKey: String = ""
        
        private let embeddingEndpoint = "https://api.openai.com/v1/embeddings"
        private let embeddingModel = "text-embedding-3-small"
        
        private let chatEndpoint = "https://api.openai.com/v1/chat/completions"
        private let visionModel = "gpt-4o"
        private let audioModel = "whisper-1"
        private let audioEndpoint = "https://api.openai.com/v1/audio/transcriptions"
        
        func setAPIKey(_ key: String) {
            self.apiKey = key
        }
        
        func generateEmbedding(for text: String) async throws -> [Float] {
            guard !apiKey.isEmpty else {
                throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key not set"])
            }
            
            var request = URLRequest(url: URL(string: embeddingEndpoint)!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let body: [String: Any] = [
                "model": embeddingModel,
                "input": text
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("API Error Response: \(responseString)")
                }
                throw NSError(domain: "OpenAIService", code: 2, 
                             userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI API"])
            }
            
            // Debug: Print the response data
            if let jsonString = String(data: data, encoding: .utf8) {
                print("Response data: \(jsonString.prefix(200))...")
            }
            
            do {
                // Try to decode using Codable
                let decoder = JSONDecoder()
                let response = try decoder.decode(EmbeddingResponse.self, from: data)
                return response.data.first?.embedding ?? []
            } catch {
                print("Decoding error: \(error)")
                
                // Fallback to manual JSON parsing
                do {
                    let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                    guard let dataArray = jsonResponse?["data"] as? [[String: Any]],
                          let firstData = dataArray.first,
                          let embedding = firstData["embedding"] as? [NSNumber] else {
                        throw NSError(domain: "OpenAIService", code: 3, 
                                     userInfo: [NSLocalizedDescriptionKey: "Failed to parse embedding from response"])
                    }
                    
                    // Convert NSNumber array to Float array
                    return embedding.map { $0.floatValue }
                } catch {
                    print("Manual parsing error: \(error)")
                    throw NSError(domain: "OpenAIService", code: 3, 
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to parse embedding from response"])
                }
            }
        }
        
        func generateImageDescription(base64Image: String) async throws -> String {
            guard !apiKey.isEmpty else {
                throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key not set"])
            }
            
            var request = URLRequest(url: URL(string: chatEndpoint)!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("application/json", forHTTPHeaderField: "Content-Type")
            
            let content: [[String: Any]] = [
                ["type": "text", "text": "Describe this image in detail."],
                ["type": "image_url", "image_url": ["url": "data:image/jpeg;base64,\(base64Image)"]]
            ]
            
            let message: [String: Any] = [
                "role": "user",
                "content": content
            ]
            
            let body: [String: Any] = [
                "model": visionModel,
                "messages": [message],
                "max_tokens": 300
            ]
            
            request.httpBody = try JSONSerialization.data(withJSONObject: body)
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("API Error Response: \(responseString)")
                }
                throw NSError(domain: "OpenAIService", code: 2, 
                             userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI Vision API"])
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let choices = jsonResponse?["choices"] as? [[String: Any]],
                      let firstChoice = choices.first,
                      let message = firstChoice["message"] as? [String: Any],
                      let content = message["content"] as? String else {
                    throw NSError(domain: "OpenAIService", code: 3, 
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to parse response from Vision API"])
                }
                
                return content
            } catch {
                print("Vision API parsing error: \(error)")
                throw NSError(domain: "OpenAIService", code: 3, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to parse response from Vision API"])
            }
        }
        
        func transcribeAudio(url: URL) async throws -> String {
            guard !apiKey.isEmpty else {
                throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key not set"])
            }
            
            // Load audio file data
            let audioData = try Data(contentsOf: url)
            
            // Get filename from URL
            let filename = url.lastPathComponent
            
            // Use existing implementation with the loaded data
            return try await transcribeAudio(audioData: audioData, filename: filename)
        }
        
        func transcribeAudio(audioData: Data, filename: String = "audio.mp3") async throws -> String {
            guard !apiKey.isEmpty else {
                throw NSError(domain: "OpenAIService", code: 1, userInfo: [NSLocalizedDescriptionKey: "API Key not set"])
            }
            
            // Create multipart form data
            let boundary = UUID().uuidString
            var request = URLRequest(url: URL(string: audioEndpoint)!)
            request.httpMethod = "POST"
            request.addValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
            request.addValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
            
            var body = Data()
            
            // Add model parameter
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"model\"\r\n\r\n".data(using: .utf8)!)
            body.append("\(audioModel)\r\n".data(using: .utf8)!)
            
            // Add file data
            body.append("--\(boundary)\r\n".data(using: .utf8)!)
            body.append("Content-Disposition: form-data; name=\"file\"; filename=\"\(filename)\"\r\n".data(using: .utf8)!)
            body.append("Content-Type: audio/mpeg\r\n\r\n".data(using: .utf8)!)
            body.append(audioData)
            body.append("\r\n".data(using: .utf8)!)
            
            // End boundary
            body.append("--\(boundary)--\r\n".data(using: .utf8)!)
            
            request.httpBody = body
            
            let (data, response) = try await URLSession.shared.data(for: request)
            
            guard let httpResponse = response as? HTTPURLResponse, 
                  httpResponse.statusCode == 200 else {
                if let responseString = String(data: data, encoding: .utf8) {
                    print("API Error Response: \(responseString)")
                }
                throw NSError(domain: "OpenAIService", code: 2, 
                             userInfo: [NSLocalizedDescriptionKey: "Invalid response from OpenAI Audio API"])
            }
            
            do {
                let jsonResponse = try JSONSerialization.jsonObject(with: data) as? [String: Any]
                guard let text = jsonResponse?["text"] as? String else {
                    throw NSError(domain: "OpenAIService", code: 3, 
                                 userInfo: [NSLocalizedDescriptionKey: "Failed to parse response from Audio API"])
                }
                
                return text
            } catch {
                print("Audio API parsing error: \(error)")
                throw NSError(domain: "OpenAIService", code: 3, 
                             userInfo: [NSLocalizedDescriptionKey: "Failed to parse response from Audio API"])
            }
        }
        
        // Compute cosine similarity between embeddings
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
    }
} 