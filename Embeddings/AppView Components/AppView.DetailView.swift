import SwiftUI
import AVKit

// MARK: - Detail View
extension AppView {
    struct DetailView: View {
        let document: Document.Model
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    // Document Header
                    DocumentHeader(document: document)
                    
                    // File Type Badge
                    FileTypeBadge(fileType: document.fileType)
                    
                    Divider()
                    
                    // Multimedia Content Preview
                    if document.isMultimedia {
                        MediaPreview(document: document, playerViewModel: playerViewModel)
                    }
                    
                    // Metadata Section
                    MetadataSection(metadata: document.metadata)
            
                    // Text Content
                    ContentSection(text: document.text)
                }
                .padding()
            }
        }
    }
} 