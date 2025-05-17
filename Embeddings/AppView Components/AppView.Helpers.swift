import SwiftUI

// MARK: - Helper Methods
extension AppView {
    static func fileTypeIcon(for fileType: Document.Handler.FileType) -> String {
        switch fileType {
        case .text:
            return "doc.text"
        case .pdf:
            return "doc.richtext"
        case .image:
            return "photo"
        case .video:
            return "film"
        case .audio:
            return "waveform"
        case .unknown:
            return "doc"
        }
    }
    
    static func fileTypeName(for fileType: Document.Handler.FileType) -> String {
        switch fileType {
        case .text:
            return "Text"
        case .pdf:
            return "PDF"
        case .image:
            return "Image"
        case .video:
            return "Video"
        case .audio:
            return "Audio"
        case .unknown:
            return "Unknown"
        }
    }
}

// Forwarding helpers from instance methods to static methods
func fileTypeIcon(for fileType: Document.Handler.FileType) -> String {
    AppView.fileTypeIcon(for: fileType)
}

func fileTypeName(for fileType: Document.Handler.FileType) -> String {
    AppView.fileTypeName(for: fileType)
} 