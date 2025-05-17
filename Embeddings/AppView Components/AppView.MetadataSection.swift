import SwiftUI

extension AppView {
    struct MetadataSection: View {
        let metadata: [String: String]
        @State private var isExpanded: Bool = true
        
        var body: some View {
            VStack(alignment: .leading) {
                Button(action: { isExpanded.toggle() }) {
                    HStack {
                        Text("Metadata")
                            .font(.headline)
                        
                        Spacer()
                        
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .foregroundColor(.secondary)
                    }
                    .padding(.bottom, 4)
                }
                .buttonStyle(.plain)
                
                if isExpanded {
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                        ForEach(metadata.keys.sorted(), id: \.self) { key in
                            if let value = metadata[key] {
                                VStack(alignment: .leading) {
                                    Text(key)
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                    
                                    Text(value)
                                        .font(.caption2)
                                        .foregroundColor(.primary)
                                }
                                .padding(8)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Material.ultraThinMaterial)
                                .cornerRadius(6)
                            }
                        }
                    }
                    .padding(.bottom)
                }
            }
            .padding()
            .background(Material.ultraThinMaterial)
            .cornerRadius(8)
        }
    }
} 