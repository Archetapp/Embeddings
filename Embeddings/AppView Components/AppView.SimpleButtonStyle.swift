import SwiftUI

struct SimpleButtonStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(Material.ultraThinMaterial)
            .cornerRadius(8)
    }
}

extension View {
    func simpleButtonStyle() -> some View {
        self.modifier(SimpleButtonStyle())
    }
} 