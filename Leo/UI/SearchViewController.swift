import AppKit

protocol SearchViewControllerDelegate: AnyObject {
    func searchViewController(_ vc: SearchViewController, didExecute result: SearchResult)
    func searchViewControllerDidRequestDismiss(_ vc: SearchViewController)
}

final class SearchViewController: NSViewController, NSTextFieldDelegate, NSTableViewDataSource, NSTableViewDelegate {

    // MARK: - Public
    weak var delegate: SearchViewControllerDelegate?
    var searchEngine: SearchEngine?

    // MARK: - Views
    private let visualEffect = NSVisualEffectView()
    private let textField = LeoSearchField()
    private let tableView = NSTableView()
    private let scrollView = NSScrollView()

    private var results: [SearchResult] = []

    private let rowHeight: CGFloat = 48
    private let fieldHeight: CGFloat = 60
    private let maxRows = 8

    override func loadView() {
        view = NSView(frame: NSRect(x: 0, y: 0, width: 640, height: fieldHeight))
        view.wantsLayer = true
        view.layer?.cornerRadius = 12
        view.layer?.masksToBounds = true
        setupVisualEffect()
        setupTextField()
        setupTable()
        updateWindowSize()
    }

    private func setupVisualEffect() {
        visualEffect.material = .hudWindow
        visualEffect.blendingMode = .behindWindow
        visualEffect.state = .active
        visualEffect.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(visualEffect)
        NSLayoutConstraint.activate([
            visualEffect.topAnchor.constraint(equalTo: view.topAnchor),
            visualEffect.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            visualEffect.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            visualEffect.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
    }

    private func setupTextField() {
        textField.translatesAutoresizingMaskIntoConstraints = false
        textField.font = NSFont.systemFont(ofSize: 28, weight: .light)
        textField.isBezeled = false
        textField.isBordered = false
        textField.focusRingType = .none
        textField.drawsBackground = false
        textField.placeholderString = "Type a keyword…"
        textField.delegate = self
        textField.leoKeyHandler = { [weak self] event in
            self?.handleKeyEvent(event) ?? false
        }

        view.addSubview(textField)
        NSLayoutConstraint.activate([
            textField.leadingAnchor.constraint(equalTo: view.leadingAnchor, constant: 20),
            textField.trailingAnchor.constraint(equalTo: view.trailingAnchor, constant: -20),
            textField.topAnchor.constraint(equalTo: view.topAnchor, constant: 12),
            textField.heightAnchor.constraint(equalToConstant: 36),
        ])
    }

    private func setupTable() {
        let col = NSTableColumn(identifier: NSUserInterfaceItemIdentifier("result"))
        col.width = 600
        tableView.addTableColumn(col)
        tableView.headerView = nil
        tableView.rowHeight = rowHeight
        tableView.backgroundColor = .clear
        tableView.selectionHighlightStyle = .regular
        tableView.intercellSpacing = NSSize(width: 0, height: 0)
        tableView.dataSource = self
        tableView.delegate = self
        tableView.allowsEmptySelection = false
        tableView.gridStyleMask = []
        tableView.action = #selector(rowClicked)
        tableView.target = self

        scrollView.documentView = tableView
        scrollView.hasVerticalScroller = true
        scrollView.drawsBackground = false
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.borderType = .noBorder
        scrollView.isHidden = true

        view.addSubview(scrollView)
        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: textField.bottomAnchor, constant: 8),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])
    }

    // MARK: - Public API used by AppDelegate / window

    func resetForShow() {
        textField.stringValue = ""
        results = []
        tableView.reloadData()
        scrollView.isHidden = true
        updateWindowSize()
        view.window?.makeFirstResponder(textField)
    }

    // MARK: - NSTextFieldDelegate

    func controlTextDidChange(_ obj: Notification) {
        runSearch()
    }

    private func runSearch() {
        let query = textField.stringValue
        results = searchEngine?.search(query) ?? []
        tableView.reloadData()
        scrollView.isHidden = results.isEmpty
        if !results.isEmpty {
            tableView.selectRowIndexes([0], byExtendingSelection: false)
        }
        updateWindowSize()
    }

    private func updateWindowSize() {
        let visibleRows = min(results.count, maxRows)
        let tableHeight = CGFloat(visibleRows) * rowHeight + (visibleRows > 0 ? 8 : 0)
        let totalHeight = fieldHeight + tableHeight
        guard let window = view.window else { return }
        var frame = window.frame
        let delta = totalHeight - frame.height
        frame.size.height = totalHeight
        frame.origin.y -= delta // grow downward
        window.setFrame(frame, display: true, animate: false)
    }

    // MARK: - Key handling

    /// Called by LeoSearchField before default NSTextField handling.
    /// Return true to consume the event, false to let the field handle it.
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        switch event.keyCode {
        case 53: // Escape
            delegate?.searchViewControllerDidRequestDismiss(self)
            return true
        case 36, 76: // Return, Enter
            executeSelected()
            return true
        case 125: // Down arrow
            moveSelection(by: 1)
            return true
        case 126: // Up arrow
            moveSelection(by: -1)
            return true
        case 48: // Tab
            autocomplete()
            return true
        default:
            return false
        }
    }

    private func moveSelection(by delta: Int) {
        guard !results.isEmpty else { return }
        let current = tableView.selectedRow
        let next = max(0, min(results.count - 1, current + delta))
        tableView.selectRowIndexes([next], byExtendingSelection: false)
        tableView.scrollRowToVisible(next)
    }

    private func autocomplete() {
        guard tableView.selectedRow >= 0, tableView.selectedRow < results.count else { return }
        let keyword = results[tableView.selectedRow].action.keyword
        textField.stringValue = keyword
        runSearch()
    }

    private func executeSelected() {
        guard tableView.selectedRow >= 0, tableView.selectedRow < results.count else { return }
        let result = results[tableView.selectedRow]
        delegate?.searchViewController(self, didExecute: result)
    }

    @objc private func rowClicked() {
        executeSelected()
    }

    // MARK: - NSTableViewDataSource / Delegate

    func numberOfRows(in tableView: NSTableView) -> Int {
        results.count
    }

    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        let identifier = NSUserInterfaceItemIdentifier("ResultCell")
        let cell = (tableView.makeView(withIdentifier: identifier, owner: self) as? ResultCellView)
            ?? ResultCellView(frame: .zero)
        cell.identifier = identifier
        cell.configure(with: results[row])
        return cell
    }
}

// MARK: - LeoSearchField

/// NSTextField subclass that forwards arrow/enter/escape/tab key events to a
/// handler before the default field editor consumes them.
final class LeoSearchField: NSTextField {
    var leoKeyHandler: ((NSEvent) -> Bool)?

    override func performKeyEquivalent(with event: NSEvent) -> Bool {
        if leoKeyHandler?(event) == true { return true }
        return super.performKeyEquivalent(with: event)
    }

    override func keyDown(with event: NSEvent) {
        if leoKeyHandler?(event) == true { return }
        super.keyDown(with: event)
    }
}
