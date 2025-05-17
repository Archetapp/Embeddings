import SwiftUI

extension AppView {
    struct StatusFooter: View {
        @ObservedObject var documentViewModel: Document.ViewActor
        
        var body: some View {
            HStack {
                if documentViewModel.isGeneratingEmbeddings {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.horizontal)
                    Text("Generating embeddings...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if documentViewModel.isAnalyzingContent {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle())
                        .padding(.horizontal)
                    Text("Analyzing content...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else {
                    Text("\(documentViewModel.documents.count) documents loaded")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                
                Spacer()
                
                Button(action: {
                    Task {
                        await documentViewModel.generateEmbeddings()
                    }
                }) {
                    Text("Generate Embeddings")
                        .foregroundColor(.primary)
                        .simpleButtonStyle()
                }
                .disabled(documentViewModel.documents.isEmpty || documentViewModel.apiKey.isEmpty || documentViewModel.isGeneratingEmbeddings)
                .opacity(documentViewModel.documents.isEmpty || documentViewModel.apiKey.isEmpty || documentViewModel.isGeneratingEmbeddings ? 0.5 : 1)
                .padding(.horizontal)
            }
            .padding(.vertical)
        }
    }
} 