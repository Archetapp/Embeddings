import SwiftUI

extension AppView {
    struct DocumentListItem: View {
        let document: Document.Model
        let isSelected: Bool
        @ObservedObject var documentViewModel: Document.ViewActor
        let onSelect: () -> Void
        @State private var thumbnail: NSImage?
        @State private var isLoadingThumbnail: Bool = false
        
        var body: some View {
            Button(action: onSelect) {
                HStack(spacing: 12) {
                    // Document type icon or thumbnail
                    if document.isMultimedia {
                        ZStack {
                            Rectangle()
                                .fill(Material.ultraThinMaterial)
                                .frame(width: 40, height: 40)
                                .cornerRadius(6)
                            
                            if let thumbnailImage = thumbnail {
                                Image(nsImage: thumbnailImage)
                                    .resizable()
                                    .aspectRatio(contentMode: .fill)
                                    .frame(width: 40, height: 40)
                                    .cornerRadius(6)
                            } else {
                                if isLoadingThumbnail {
                                    ProgressView()
                                        .frame(width: 40, height: 40)
                                } else {
                                    Image(systemName: fileTypeIcon(for: document.fileType))
                                        .font(.system(size: 16))
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                        .id(document.id) // Ensure SwiftUI creates unique views for each document
                        .onAppear {
                            loadThumbnail()
                        }
                        .onDisappear {
                            // Stop accessing when the view disappears
                            if document.isMultimedia {
                                document.stopAccessingSecurityScopedResource()
                            }
                            
                            // Clear thumbnail to free memory when scrolled out of view
                            thumbnail = nil
                        }
                    } else {
                        Image(systemName: fileTypeIcon(for: document.fileType))
                            .font(.system(size: 20))
                            .frame(width: 40, height: 40)
                            .foregroundColor(.primary)
                    }
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text(document.name)
                            .font(.headline)
                            .foregroundColor(.primary)
                        
                        Text(document.text.prefix(60) + (document.text.count > 60 ? "..." : ""))
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(2)
                        
                        HStack {
                            if !documentViewModel.searchQuery.isEmpty {
                                if documentViewModel.searchEmbedding != nil && document.embedding != nil {
                                    // Show similarity score from embedding if available
                                    let similarity = documentViewModel.embeddingService.cosineSimilarity(
                                        between: documentViewModel.searchEmbedding!, 
                                        and: document.embedding!
                                    )
                                    Text("Similarity: \(Int(similarity * 100))%")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Material.ultraThinMaterial)
                                        )
                                        .foregroundColor(
                                            similarity > 0.8 ? .green :
                                            similarity > 0.5 ? .orange : 
                                            .red
                                        )
                                } else if documentViewModel.searchEmbedding == nil && 
                                          (document.name.lowercased().contains(documentViewModel.searchQuery.lowercased()) ||
                                           document.text.lowercased().contains(documentViewModel.searchQuery.lowercased())) {
                                    // Show text match badge for simple text search
                                    Text("Match")
                                        .font(.caption)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(
                                            Capsule()
                                                .fill(Material.ultraThinMaterial)
                                        )
                                        .foregroundColor(.blue)
                                }
                            }
                            
                            Spacer()
                            
                            if document.isEmbedded {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundColor(.green)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(isSelected ? Material.ultraThickMaterial : Material.ultraThinMaterial)
                .cornerRadius(8)
            }
            .buttonStyle(PlainButtonStyle())
            .id(document.id) // Add an ID to the entire button to ensure uniqueness
        }
        
        private func loadThumbnail() {
            // Only attempt to load if we don't already have a thumbnail and aren't currently loading
            guard thumbnail == nil && !isLoadingThumbnail else { return }
            
            isLoadingThumbnail = true
            
            // Start accessing the resource if it's a multimedia file
            if document.isMultimedia {
                _ = document.startAccessingSecurityScopedResource()
            }
            
            // Use a background task to load the thumbnail
            Task {
                // Print the document name and ID to debug
                print("Loading thumbnail for: \(document.name), ID: \(document.id)")
                
                // Create a unique thumbnail for this document
                if let image = document.thumbnail {
                    // Create a tiny thumbnail for the list item
                    let smallThumbnail = image.thumbnailImage(maxSize: 60)
                    
                    // Update UI on main thread
                    DispatchQueue.main.async {
                        if !Task.isCancelled {
                            self.thumbnail = smallThumbnail
                            self.isLoadingThumbnail = false
                        }
                    }
                } else {
                    DispatchQueue.main.async {
                        if !Task.isCancelled {
                            self.isLoadingThumbnail = false
                        }
                    }
                }
            }
        }
    }
} 