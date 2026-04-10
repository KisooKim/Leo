import AppKit

/// Borderless, floating, non-activating panel that hosts the search UI.
final class SearchWindow: NSPanel {
    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 640, height: 60),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.isFloatingPanel = true
        self.level = .floating
        self.backgroundColor = .clear
        self.isOpaque = false
        self.hasShadow = true
        self.isMovableByWindowBackground = false
        self.hidesOnDeactivate = true
        self.becomesKeyOnlyIfNeeded = false
        self.titlebarAppearsTransparent = true
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }

    /// Position horizontally centered, vertically 1/3 from the top, on the
    /// screen that currently contains the mouse cursor.
    func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { $0.frame.contains(mouse) } ?? NSScreen.main ?? NSScreen.screens[0]
        let frame = screen.visibleFrame
        let width = self.frame.width
        let height = self.frame.height
        let x = frame.midX - width / 2
        let y = frame.maxY - (frame.height / 3) - height
        self.setFrameOrigin(NSPoint(x: x, y: y))
    }
}
