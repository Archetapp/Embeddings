import SwiftUI
import CorePersistence

extension AppView {
    struct DocumentList: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @Binding var selectedDocument: Document.Model?
        @ObservedObject var playerViewModel: PlayerViewModel
        
        // Pagination states
        @State private var currentPage = 0
        @State private var itemsPerPage = 50
        
        // Available page sizes
        private let pageSizeOptions = [25, 50, 100, 200]
        
        var body: some View {
            mainContent
                .padding(.horizontal)
                .onChange(of: documentsToShow.count) { _, _ in
                    currentPage = 0
                }
        }
        
        @ViewBuilder
        private var mainContent: some View {
            VStack(spacing: 0) {
                paginationHeader
                documentScrollView
                paginationFooter
            }
        }
        
        @ViewBuilder 
        private var documentScrollView: some View {
            ScrollView {
                LazyVStack(spacing: 8) {
                    ForEach(paginatedDocuments) { document in
                        createDocumentListItem(for: document)
                    }
                }
                .padding(.horizontal)
            }
        }
        
        private func createDocumentListItem(for document: Document.Model) -> some View {
            let isSelected = selectedDocument?.id == document.id
            
            return DocumentListItem(
                document: document,
                isSelected: isSelected,
                documentViewModel: documentViewModel,
                onSelect: {
                    handleDocumentSelection(document)
                }
            )
            .onTapGesture {
                handleDocumentSelection(document)
            }
            .id(document.id)
        }
        
        @ViewBuilder
        private var paginationHeader: some View {
            if totalPages > 1 {
                HStack {
                    pageInfo
                    Spacer()
                    pageSizePicker
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Material.ultraThinMaterial)
            }
        }
        
        private var pageInfo: some View {
            Text("Page \(currentPage + 1) of \(totalPages)")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        
        private var pageSizePicker: some View {
            Picker("Items per page", selection: $itemsPerPage) {
                ForEach(pageSizeOptions, id: \.self) { size in
                    Text("\(size)").tag(size)
                }
            }
            .pickerStyle(.menu)
            .frame(width: 80)
            .onChange(of: itemsPerPage) { _, _ in
                currentPage = 0
            }
        }
        
        @ViewBuilder
        private var paginationFooter: some View {
            if totalPages > 1 {
                HStack {
                    previousButton
                    pageNumbers
                    nextButton
                }
                .padding(.horizontal)
                .padding(.vertical, 8)
                .background(Material.ultraThinMaterial)
            }
        }
        
        private var previousButton: some View {
            Button(action: { currentPage = max(0, currentPage - 1) }) {
                Image(systemName: "chevron.left")
            }
            .disabled(currentPage == 0)
        }
        
        private var nextButton: some View {
            Button(action: { currentPage = min(totalPages - 1, currentPage + 1) }) {
                Image(systemName: "chevron.right")
            }
            .disabled(currentPage == totalPages - 1)
        }
        
        @ViewBuilder
        private var pageNumbers: some View {
            ForEach(visiblePageNumbers, id: \.self) { pageNumber in
                pageButton(for: pageNumber)
            }
        }
        
        private func pageButton(for pageNumber: Int) -> some View {
            Button(action: { currentPage = pageNumber }) {
                Text("\(pageNumber + 1)")
                    .font(.caption)
                    .foregroundColor(currentPage == pageNumber ? .white : .primary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(currentPage == pageNumber ? Color.accentColor : Color.clear)
                    .cornerRadius(4)
            }
        }
        
        private func handleDocumentSelection(_ document: Document.Model) {
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
        
        // Computed properties for pagination
        private var documentsToShow: IdentifierIndexingArrayOf<Document.Model> {
            let sortedResults = documentViewModel.sortedResults
            let allDocuments = documentViewModel.documents
            return sortedResults.isEmpty ? allDocuments : sortedResults
        }
        
        private var totalPages: Int {
            let count = documentsToShow.count
            let pages = Int(ceil(Double(count) / Double(itemsPerPage)))
            return max(1, pages)
        }
        
        private var paginatedDocuments: [Document.Model] {
            let startIndex = currentPage * itemsPerPage
            let endIndex = min(startIndex + itemsPerPage, documentsToShow.count)
            
            guard startIndex < documentsToShow.count else {
                return []
            }
            
            return Array(documentsToShow[startIndex..<endIndex])
        }
        
        private var visiblePageNumbers: [Int] {
            let maxVisiblePages = 5
            let halfVisible = maxVisiblePages / 2
            
            var start = max(0, currentPage - halfVisible)
            var end = min(totalPages - 1, start + maxVisiblePages - 1)
            
            // Adjust start if we're near the end
            if end - start < maxVisiblePages - 1 {
                start = max(0, end - maxVisiblePages + 1)
            }
            
            return Array(start...end)
        }
    }
}
