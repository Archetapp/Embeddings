import SwiftUI

// MARK: - Placeholder View
extension AppView {
    struct PlaceholderView: View {
        var body: some View {
            VStack {
                Spacer()
                
                Image(systemName: "doc.text.magnifyingglass")
                    .font(.system(size: 60))
                    .foregroundColor(.secondary)
                
                Text("Select a document to view its content")
                    .font(.title2)
                    .foregroundColor(.secondary)
                    .padding(.top)
                
                Spacer()
            }
        }
    }
} 