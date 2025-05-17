import SwiftUIX

@main
struct EmbeddingsApp: App {
    var body: some Scene {
        WindowGroup {
            AppView()
                .preferredColorScheme(.dark)
                .onAppear {
                    setupAppearance()
                }
                .background(VisualEffectView(effect: .fullScreenUI))
        }
        .windowStyle(HiddenTitleBarWindowStyle())
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Import Files...") {
                    NotificationCenter.default.post(name: NSNotification.Name("ImportFiles"), object: nil)
                }
                .keyboardShortcut("o", modifiers: .command)
            }
        }
    }
    
    private func setupAppearance() {
        // Set the appearance for all windows
        NSApp.appearance = NSAppearance(named: .darkAqua)
        
        // Configure window appearance when available
        for window in NSApp.windows {
            window.titlebarAppearsTransparent = true
            window.isOpaque = false
            
            // Set minimum window size
            window.setFrame(NSRect(x: window.frame.origin.x, 
                                 y: window.frame.origin.y, 
                                 width: max(window.frame.width, 1000), 
                                 height: max(window.frame.height, 700)), 
                          display: true)
            window.minSize = NSSize(width: 1000, height: 700)
            
            // Enable file dragging for the entire window
            window.registerForDraggedTypes([NSPasteboard.PasteboardType.fileURL])
        }
    }
    
    // MARK: - Visual Effect View
    struct VisualEffectView: NSViewRepresentable {
        let effect: NSVisualEffectView.Material
        
        func makeNSView(context: Context) -> NSVisualEffectView {
            let view = NSVisualEffectView()
            view.material = effect
            view.blendingMode = .behindWindow
            view.state = .active
            return view
        }
        
        func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
            nsView.material = effect
        }
    }
} 