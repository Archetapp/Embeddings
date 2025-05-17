import SwiftUI

extension AppView {
    struct DocumentList: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var selectedDocument: Document.Model?
        @ObservedObject var playerViewModel: PlayerViewModel
        
        var body: some View {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(documentViewModel.sortedResults.isEmpty ? documentViewModel.documents : documentViewModel.sortedResults) { document in
                        DocumentListItem(
                            document: document,
                            isSelected: selectedDocument?.id == document.id,
                            documentViewModel: documentViewModel,
                            onSelect: {
                                // Stop accessing the previous document if there was one
                                if let prevDoc = selectedDocument, prevDoc.isMultimedia {
                                    prevDoc.stopAccessingSecurityScopedResource()
                                }
                                
                                selectedDocument = document
                                
                                // Start accessing the new document if it's multimedia
                                if document.isMultimedia {
                                    _ = document.startAccessingSecurityScopedResource()
                                }
                                
                                // Prepare player if it's a video
                                if document.fileType == .video {
                                    playerViewModel.preparePlayer(for: document.url)
                                }
                            }
                        )
                        // Use the document ID to ensure views are properly created/recycled
                        .id(document.id)
                    }
                }
                .padding(.horizontal)
            }
            .frame(maxHeight: .infinity)
        }
    }
} 