import AppKit
import SwiftUI

final class QuickAddWindow: NSPanel {
    var onSave: ((Action) -> Void)?
    var onCancel: (() -> Void)?

    private var hosting: NSHostingController<QuickAddView>!

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

        // Create the hosting controller with placeholder closures first,
        // then rewire the rootView with weak-self closures after `self`
        // is fully constructed. This avoids the retain cycle caused by
        // capturing `self` (or a local mutable box) inside the init closure.
        hosting = NSHostingController(rootView: QuickAddView(
            onSave: { _ in },
            onCancel: { }
        ))
        hosting.view.frame = NSRect(x: 0, y: 0, width: 480, height: 400)
        self.contentViewController = hosting
        self.center()

        hosting.rootView = QuickAddView(
            onSave: { [weak self] action in
                self?.onSave?(action)
                self?.close()
            },
            onCancel: { [weak self] in
                self?.onCancel?()
                self?.close()
            }
        )
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}
