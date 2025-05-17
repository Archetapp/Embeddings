import SwiftUI

extension Document {
    struct DetailView: View {
        let document: Document.Model
        
        var body: some View {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    HStack {
                        Text(document.name)
                            .font(.largeTitle)
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
                    
                    Divider()
                    
                    Text(document.text)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Material.ultraThinMaterial)
                        .cornerRadius(8)
                }
                .padding()
            }
            .background(Material.regular)
        }
    }
} 