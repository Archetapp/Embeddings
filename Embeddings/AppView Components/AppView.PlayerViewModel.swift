import SwiftUI
import AVKit

// Player view model to retain the AVPlayer instance
class PlayerViewModel: ObservableObject {
    @Published var player: AVPlayer?
    private var currentURL: URL?
    
    func preparePlayer(for url: URL) {
        // Store the URL we're preparing
        currentURL = url
        
        // Create asset with proper options for network access
        let asset = AVURLAsset(url: url)
        let playerItem = AVPlayerItem(asset: asset)
        
        // Create player and set it
        self.player = AVPlayer(playerItem: playerItem)
        
        // Auto-play when ready
        player?.play()
    }
    
    deinit {
        // Clean up player
        player?.pause()
        player = nil
    }
} 
