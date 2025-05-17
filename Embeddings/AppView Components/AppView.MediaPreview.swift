import SwiftUI
import AVKit

extension AppView {
    struct MediaPreview: View {
        let document: Document.Model
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            VStack(alignment: .leading) {
                Text("Media Preview")
                    .font(.headline)
                    .padding(.bottom, 4)
                
                Group {
                    if document.fileType == .image {
                        ImagePreview(document: document)
                    } else if document.fileType == .video {
                        VideoPreview(document: document, playerViewModel: playerViewModel)
                    } else if document.fileType == .audio {
                        AudioPreview()
                    }
                }
                .frame(minHeight: 300)
                .id(document.id)
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
} 