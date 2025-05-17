import SwiftUI

// MARK: - Sidebar View
extension AppView {
    struct Sidebar: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var selectedDocument: Document.Model?
        @ObservedObject var playerViewModel: PlayerViewModel
        @Binding var isImporting: Bool
        @State private var showingAPIKeyAlert = false
        @State private var tempAPIKey = ""
        
        var body: some View {
            VStack(spacing: 0) {
                // Header with title and toolbar buttons
                SidebarHeader(
                    documentViewModel: documentViewModel,
                    isImporting: $isImporting
                )
                
                // API Key and Search
                SearchBar(
                    documentViewModel: documentViewModel,
                    showingAPIKeyAlert: $showingAPIKeyAlert,
                    tempAPIKey: $tempAPIKey
                )
                
                // Document List
                DocumentList(
                    documentViewModel: documentViewModel,
                    selectedDocument: $selectedDocument,
                    playerViewModel: playerViewModel
                )
                
                // Status and Control Buttons
                StatusFooter(documentViewModel: documentViewModel)
            }
            .alert("OpenAI API Key", isPresented: $showingAPIKeyAlert) {
                TextField("Enter your API key", text: $tempAPIKey)
                    .foregroundColor(.primary)
                
                Button("Save") {
                    documentViewModel.apiKey = tempAPIKey
                }
                
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Please enter your OpenAI API key to generate embeddings.")
            }
        }
    }
} 