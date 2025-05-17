import Foundation
import SwiftUI
import UniformTypeIdentifiers
import CorePersistence
import Cocoa

enum Document {
    // This enum serves as a namespace for Document-related types
}

// MARK: - Image Resizing Utilities
extension NSImage {
    func resized(to newSize: NSSize) -> NSImage {
        let img = NSImage(size: newSize)
        
        img.lockFocus()
        let ctx = NSGraphicsContext.current
        ctx?.imageInterpolation = .high
        self.draw(in: NSRect(origin: .zero, size: newSize),
                 from: NSRect(origin: .zero, size: self.size),
                 operation: .copy,
                 fraction: 1.0)
        img.unlockFocus()
        
        return img
    }
    
    func thumbnailImage(maxSize: CGFloat = 200) -> NSImage {
        let ratio = min(maxSize / size.width, maxSize / size.height)
        let newSize = NSSize(width: size.width * ratio, height: size.height * ratio)
        return resized(to: newSize)
    }
}

extension Document {
    struct Model: Identifiable, Hashable, Codable, Sendable {
        typealias ID = _TypeAssociatedID<Self, UUID>
        
        let id: ID
        let name: String
        let text: String
        var embedding: [Float]?
        let url: URL
        let fileType: Handler.FileType
        let metadata: [String: String]
        
        // Thumbnail URL instead of NSImage for Codable support
        let thumbnailURL: URL?
        
        // Security-scoped bookmark data for maintaining access to files
        let securityScopedBookmark: Data?
        
        // Non-persisted, computed property for the thumbnail
        var thumbnail: NSImage? {
            guard let thumbnailURL = thumbnailURL else { return nil }
            
            // If this is a direct access to an image file (not our cached thumbnail), use security scope
            if fileType == .image && thumbnailURL == url {
                // Access security-scoped resource if needed
                var didStartAccess = false
                if let bookmark = securityScopedBookmark {
                    do {
                        var isStale = false
                        let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                        didStartAccess = resolvedURL.startAccessingSecurityScopedResource()
                        // Use the resolved URL to load the image
                        if let image = NSImage(contentsOf: resolvedURL) {
                            let thumbnailImage = image.thumbnailImage(maxSize: 800)
                            if didStartAccess {
                                resolvedURL.stopAccessingSecurityScopedResource()
                            }
                            return thumbnailImage
                        }
                        if didStartAccess {
                            resolvedURL.stopAccessingSecurityScopedResource()
                        }
                        return nil
                    } catch {
                        print("Error resolving bookmark for thumbnail: \(error)")
                        if didStartAccess {
                            url.stopAccessingSecurityScopedResource()
                        }
                    }
                }
            }
            
            // For cached thumbnails or if security scope failed
            if let image = NSImage(contentsOf: thumbnailURL) {
                return image.thumbnailImage(maxSize: 800)
            }
            return nil
        }
        
        var isEmbedded: Bool {
            return embedding != nil
        }
        
        var isMultimedia: Bool {
            return fileType == .image || fileType == .video || fileType == .audio
        }
        
        // Metadata string for embedding inclusion
        var metadataString: String {
            var result = ""
            for (key, value) in metadata {
                result += "\(key): \(value)\n"
            }
            return result
        }
        
        // Full text with metadata for embedding
        var fullText: String {
            return "Metadata:\n\(metadataString)\nContent:\n\(text)"
        }
        
        // Codable implementation for FileType enum
        enum CodingKeys: String, CodingKey {
            case id, name, text, embedding, url, fileType, thumbnailURL, securityScopedBookmark, metadata
        }
        
        init(name: String, text: String, embedding: [Float]?, url: URL, fileType: Handler.FileType, thumbnailURL: URL? = nil, securityScopedBookmark: Data? = nil, metadata: [String: String] = [:]) {
            self.id = .random()
            self.name = name
            self.text = text
            self.embedding = embedding
            self.url = url
            self.fileType = fileType
            self.thumbnailURL = thumbnailURL
            self.securityScopedBookmark = securityScopedBookmark
            self.metadata = metadata
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            id = try container.decode(ID.self, forKey: .id)
            name = try container.decode(String.self, forKey: .name)
            text = try container.decode(String.self, forKey: .text)
            embedding = try container.decodeIfPresent([Float].self, forKey: .embedding)
            url = try container.decode(URL.self, forKey: .url)
            fileType = try container.decode(Handler.FileType.self, forKey: .fileType)
            thumbnailURL = try container.decodeIfPresent(URL.self, forKey: .thumbnailURL)
            securityScopedBookmark = try container.decodeIfPresent(Data.self, forKey: .securityScopedBookmark)
            metadata = try container.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
        }
        
        func encode(to encoder: Encoder) throws {
            var container = encoder.container(keyedBy: CodingKeys.self)
            try container.encode(id, forKey: .id)
            try container.encode(name, forKey: .name)
            try container.encode(text, forKey: .text)
            try container.encodeIfPresent(embedding, forKey: .embedding)
            try container.encode(url, forKey: .url)
            try container.encode(fileType, forKey: .fileType)
            try container.encodeIfPresent(thumbnailURL, forKey: .thumbnailURL)
            try container.encodeIfPresent(securityScopedBookmark, forKey: .securityScopedBookmark)
            try container.encode(metadata, forKey: .metadata)
        }
        
        func hash(into hasher: inout Hasher) {
            hasher.combine(id)
        }
        
        static func == (lhs: Document.Model, rhs: Document.Model) -> Bool {
            lhs.id == rhs.id
        }
        
        // Helper method to access the original file with security scope
        func startAccessingSecurityScopedResource() -> Bool {
            guard let bookmark = securityScopedBookmark else {
                return false
            }
            
            do {
                var isStale = false
                let resolvedURL = try URL(resolvingBookmarkData: bookmark, options: .withSecurityScope, relativeTo: nil, bookmarkDataIsStale: &isStale)
                
                if isStale {
                    print("Warning: Bookmark is stale for \(name)")
                }
                
                return resolvedURL.startAccessingSecurityScopedResource()
            } catch {
                print("Error accessing security-scoped resource for \(name): \(error)")
                return false
            }
        }
        
        func stopAccessingSecurityScopedResource() {
            if securityScopedBookmark != nil {
                url.stopAccessingSecurityScopedResource()
            }
        }
    }
} 
