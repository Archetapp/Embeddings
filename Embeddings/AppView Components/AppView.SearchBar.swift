import SwiftUI

extension AppView {
    struct SearchBar: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        @State private var debouncedText: String = ""
        @State private var debounceTask: Task<Void, Never>?
        
        var body: some View {
            HStack {
                TextField("Search...", text: $documentViewModel.searchQuery)
                    .textFieldStyle(.plain)
                    .padding(6)
                    .background(Material.bar)
                    .cornerRadius(8)
                    .onChange(of: documentViewModel.searchQuery) { _, newText in
                        // Cancel any previous debounce task
                        debounceTask?.cancel()
                        
                        // Create a new debounce task with a longer delay for better performance
                        debounceTask = Task {
                            do {
                                // Increase delay to 800ms to reduce frequency of searches
                                try await Task.sleep(nanoseconds: 800_000_000)
                                
                                // If task wasn't cancelled during the sleep, update the debounced text
                                if !Task.isCancelled {
                                    debouncedText = newText
                                    await documentViewModel.performSearch()
                                }
                            } catch {
                                // Task was cancelled or failed, do nothing
                            }
                        }
                    }
                    .background(Material.ultraThinMaterial)
                    .cornerRadius(8)
                    .padding(.horizontal)
            }
            .padding(.bottom)
        }
    }
}
