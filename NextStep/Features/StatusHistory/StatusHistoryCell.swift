import UIKit

/// Displays one status-history row. The cell only assigns pre-formatted text; all business
/// formatting lives in `StatusHistoryRowModel`.
@MainActor
final class StatusHistoryCell: UITableViewCell {
    static let reuseIdentifier = "StatusHistoryCell"

    private let transitionLabel = UILabel()
    private let timeLabel = UILabel()
    private let noteLabel = UILabel()

    override init(style: UITableViewCell.CellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        setUpSubviews()
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    func configure(with row: StatusHistoryRowModel) {
        transitionLabel.text = row.transitionText
        timeLabel.text = row.timeText
        noteLabel.text = row.noteText
        noteLabel.isHidden = row.noteText == nil
    }

    private func setUpSubviews() {
        selectionStyle = .none

        transitionLabel.font = .preferredFont(forTextStyle: .headline)
        transitionLabel.adjustsFontForContentSizeCategory = true
        transitionLabel.numberOfLines = 0

        timeLabel.font = .preferredFont(forTextStyle: .caption1)
        timeLabel.adjustsFontForContentSizeCategory = true
        timeLabel.textColor = .secondaryLabel
        timeLabel.numberOfLines = 0

        noteLabel.font = .preferredFont(forTextStyle: .subheadline)
        noteLabel.adjustsFontForContentSizeCategory = true
        noteLabel.textColor = .secondaryLabel
        noteLabel.numberOfLines = 0

        let stack = UIStackView(arrangedSubviews: [transitionLabel, timeLabel, noteLabel])
        stack.axis = .vertical
        stack.spacing = 3
        stack.translatesAutoresizingMaskIntoConstraints = false
        contentView.addSubview(stack)

        let margins = contentView.layoutMarginsGuide
        NSLayoutConstraint.activate([
            stack.leadingAnchor.constraint(equalTo: margins.leadingAnchor),
            stack.trailingAnchor.constraint(equalTo: margins.trailingAnchor),
            stack.topAnchor.constraint(equalTo: margins.topAnchor),
            stack.bottomAnchor.constraint(equalTo: margins.bottomAnchor)
        ])
    }
}
