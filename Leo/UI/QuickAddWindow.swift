import AppKit
import SwiftUI

final class QuickAddWindow: NSPanel {
    var onSave: ((Action) -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 480, height: 400),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        self.title = "Add Action"
        self.isFloatingPanel = true
        self.level = .floating
        self.isReleasedWhenClosed = false

        var capturedSelf: QuickAddWindow?
        let view = QuickAddView(
            onSave: { action in
                capturedSelf?.onSave?(action)
                capturedSelf?.close()
            },
            onCancel: {
                capturedSelf?.onCancel?()
                capturedSelf?.close()
            }
        )
        let hosting = NSHostingController(rootView: view)
        hosting.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        self.contentViewController = hosting
        capturedSelf = self

        self.center()
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
