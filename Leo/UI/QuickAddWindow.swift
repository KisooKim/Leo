import AppKit
import SwiftUI

final class QuickAddWindow: NSPanel {
    var onSave: ((Action) -> Void)?
    var onCancel: (() -> Void)?

    init() {
        super.init(
            contentRect: NSRect(x: 0, y: 0, width: 460, height: 380),
            styleMask: [.titled, .closable, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        self.title = "Add Action"
        self.isFloatingPanel = true
        self.level = .floating
        self.center()

        let view = QuickAddView(
            onSave: { [weak self] action in
                self?.onSave?(action)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.onCancel?()
                self?.close()
            }
        )
        let hosting = NSHostingController(rootView: view)
        self.contentViewController = hosting
    }

    override var canBecomeKey: Bool { true }
}
