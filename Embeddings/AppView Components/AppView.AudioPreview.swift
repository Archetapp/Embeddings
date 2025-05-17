import SwiftUI

extension AppView {
    struct AudioPreview: View {
        var body: some View {
            HStack {
                Image(systemName: "waveform")
                    .font(.system(size: 40))
                    .foregroundColor(.secondary)
                
                Text("Audio Player")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .frame(height: 100)
            .frame(maxWidth: .infinity)
            .background(Material.thin)
            .cornerRadius(8)
        }
    }
} 