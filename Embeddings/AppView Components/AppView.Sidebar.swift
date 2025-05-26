import SwiftUI

// MARK: - Sidebar View
extension AppView {
    struct Sidebar: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var selectedDocument: Document.Model?
        @ObservedObject var playerViewModel: PlayerViewModel
        @Binding var isImporting: Bool
        
        var body: some View {
            VStack(spacing: 0) {
                // Header with title and toolbar buttons
                SidebarHeader(
                    documentViewModel: documentViewModel,
                    isImporting: $isImporting
                )
                
                // Search Bar
                SearchBar(
                    documentViewModel: documentViewModel
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
        }
    }
}
