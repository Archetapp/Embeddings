import SwiftUI

extension AppView {
    struct FileTypeBadge: View {
        let fileType: Document.Handler.FileType
        
        var body: some View {
            HStack {
                Label(
                    fileTypeName(for: fileType),
                    systemImage: fileTypeIcon(for: fileType)
                )
                .foregroundColor(.secondary)
                .padding(6)
                .background(Material.ultraThinMaterial)
                .cornerRadius(8)
                
                Spacer()
            }
        }
    }
} 