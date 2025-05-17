import SwiftUI

extension AppView {
    struct ImagePreview: View {
        let document: Document.Model
        @State private var displayImage: NSImage?
        
        var body: some View {
            ZStack {
                Rectangle()
                    .fill(Material.thin)
                    .frame(maxHeight: 300)
                    .cornerRadius(8)
                
                if let image = displayImage {
                    Image(nsImage: image)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 300)
                        .cornerRadius(8)
                } else {
                    VStack {
                        Image(systemName: "photo")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Unable to load image")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .onAppear {
                loadImage()
            }
            .onDisappear {
                document.stopAccessingSecurityScopedResource()
                displayImage = nil
            }
        }
        
        private func loadImage() {
            // Start accessing the resource
            let _ = document.startAccessingSecurityScopedResource()
            
            // Load the image, resize and cache for display
            if let image = document.thumbnail {
                let maxDimension: CGFloat = 800
                let ratio = min(maxDimension / image.size.width, maxDimension / image.size.height)
                if ratio < 1.0 {
                    // Only resize if the image is larger than our target size
                    displayImage = image.resized(to: NSSize(
                        width: image.size.width * ratio,
                        height: image.size.height * ratio
                    ))
                } else {
                    displayImage = image
                }
            }
        }
    }
} 