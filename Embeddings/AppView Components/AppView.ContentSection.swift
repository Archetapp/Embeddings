import SwiftUI

extension AppView {
    struct ContentSection: View {
        let text: String
        
        var body: some View {
            Text("Content")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Material.ultraThinMaterial)
                .cornerRadius(8)
        }
    }
} 


extension AppView {
    struct SummarySection: View {
        let text: String
        
        var body: some View {
            Text("Summary")
                .font(.headline)
                .padding(.bottom, 4)
            
            Text(text)
                .font(.body)
                .foregroundColor(.primary)
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Material.ultraThinMaterial)
                .cornerRadius(8)
        }
    }
}
