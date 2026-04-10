import AppKit

final class ResultCellView: NSTableCellView {
    private let iconView = NSImageView()
    private let titleLabel = NSTextField(labelWithString: "")
    private let keywordLabel = NSTextField(labelWithString: "")

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setupViews()
    }

    required init?(coder: NSCoder) {
        super.init(coder: coder)
        setupViews()
    }

    private func setupViews() {
        iconView.translatesAutoresizingMaskIntoConstraints = false
        iconView.contentTintColor = .secondaryLabelColor
        iconView.symbolConfiguration = NSImage.SymbolConfiguration(pointSize: 18, weight: .regular)

        titleLabel.translatesAutoresizingMaskIntoConstraints = false
        titleLabel.font = NSFont.systemFont(ofSize: 16, weight: .regular)
        titleLabel.textColor = .labelColor
        titleLabel.lineBreakMode = .byTruncatingTail
        titleLabel.maximumNumberOfLines = 1

        keywordLabel.translatesAutoresizingMaskIntoConstraints = false
        keywordLabel.font = NSFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        keywordLabel.textColor = .tertiaryLabelColor
        keywordLabel.alignment = .right

        addSubview(iconView)
        addSubview(titleLabel)
        addSubview(keywordLabel)

        NSLayoutConstraint.activate([
            iconView.leadingAnchor.constraint(equalTo: leadingAnchor, constant: 16),
            iconView.centerYAnchor.constraint(equalTo: centerYAnchor),
            iconView.widthAnchor.constraint(equalToConstant: 22),
            iconView.heightAnchor.constraint(equalToConstant: 22),

            titleLabel.leadingAnchor.constraint(equalTo: iconView.trailingAnchor, constant: 12),
            titleLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
            titleLabel.trailingAnchor.constraint(lessThanOrEqualTo: keywordLabel.leadingAnchor, constant: -12),

            keywordLabel.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -16),
            keywordLabel.centerYAnchor.constraint(equalTo: centerYAnchor),
        ])
    }

    func configure(with result: SearchResult) {
        iconView.image = NSImage(systemSymbolName: iconName(for: result.action.type),
                                 accessibilityDescription: nil)
        titleLabel.stringValue = result.displayTitle
        keywordLabel.stringValue = result.action.keyword
    }

    private func iconName(for type: ActionType) -> String {
        switch type {
        case .openFolder: return "folder"
        case .openFile:   return "doc"
        case .runBash:    return "terminal"
        case .webSearch:  return "globe"
        }
    }
}
