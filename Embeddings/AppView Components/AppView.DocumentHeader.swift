import SwiftUI

extension AppView {
    struct DocumentHeader: View {
        let document: Document.Model
        
        var body: some View {
            HStack {
                Text(document.name)
                    .font(.title)
                    .bold()
                    .foregroundColor(.primary)
                
                Spacer()
                
                if document.isEmbedded {
                    Label("Embedded", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                } else {
                    Label("Not Embedded", systemImage: "circle")
                        .foregroundColor(.secondary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
            }
        }
    }
} 