import SwiftUI

extension AppView {
    struct SidebarHeader: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var isImporting: Bool
        @State private var showingSettings = false
        
        var body: some View {
            HStack {
                Text("Embeddings")
                    .font(.title)
                    .foregroundColor(.primary)
                    .padding(.leading)
                
                Spacer()
                
                Button(action: {
                    showingSettings = true
                }) {
                    Image(systemName: "gearshape.fill")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
                
                Button(action: {
                    documentViewModel.clearAllDocuments()
                }) {
                    Image(systemName: "trash")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .disabled(documentViewModel.documents.isEmpty)
                .opacity(documentViewModel.documents.isEmpty ? 0.5 : 1)
                
                Button(action: {
                    isImporting = true
                }) {
                    Image(systemName: "plus")
                        .foregroundColor(.primary)
                        .padding(8)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding(.trailing)
            }
            .padding(.top)
            .padding(.bottom, 8)
            .sheet(isPresented: $showingSettings) {
                SettingsView()
            }
        }
    }
}
