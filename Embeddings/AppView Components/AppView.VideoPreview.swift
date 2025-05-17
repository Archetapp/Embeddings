import SwiftUI
import AVKit

extension AppView {
    struct VideoPreview: View {
        let document: Document.Model
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            if let player = playerViewModel.player {
                VideoPlayer(player: player)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                        document.stopAccessingSecurityScopedResource()
                    }
            } else {
                Text("Video could not be loaded")
                    .foregroundColor(.secondary)
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .background(Material.thin)
                    .cornerRadius(8)
            }
        }
    }
} 