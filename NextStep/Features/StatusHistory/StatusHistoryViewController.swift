import os
import UIKit

/// The app's only UIKit/MVC screen: a read-only status timeline for one application.
///
/// There is no ViewModel. The injected repository is the single data source and the screen never
/// touches `ModelContext`; ordering (changedAt descending, id tie-break) is provided by the
/// repository's `statusChanges(for:)`. A fresh controller is created for each sheet presentation, so
/// reopening after a status change fetches the history again.
@MainActor
final class StatusHistoryViewController: UIViewController {
    private nonisolated enum Section: Hashable {
        case main
    }

    private let repository: any ApplicationRepository
    private let applicationID: UUID
    private let calendar: Calendar
    private let locale: Locale

    private let tableView = UITableView(frame: .zero, style: .insetGrouped)
    private var dataSource: UITableViewDiffableDataSource<Section, StatusHistoryRowModel>!

    init(
        repository: any ApplicationRepository,
        applicationID: UUID,
        calendar: Calendar = .autoupdatingCurrent,
        locale: Locale = Locale(identifier: "zh_CN")
    ) {
        self.repository = repository
        self.applicationID = applicationID
        self.calendar = calendar
        self.locale = locale
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        title = "状态历史"
        navigationItem.largeTitleDisplayMode = .never
        navigationItem.rightBarButtonItem = UIBarButtonItem(
            title: "完成",
            primaryAction: UIAction { [weak self] _ in
                self?.dismiss(animated: true)
            }
        )
        setUpTableView()
        loadStatusChanges()
    }

    private func setUpTableView() {
        view.backgroundColor = .systemGroupedBackground
        tableView.translatesAutoresizingMaskIntoConstraints = false
        tableView.rowHeight = UITableView.automaticDimension
        tableView.estimatedRowHeight = 72
        tableView.register(
            StatusHistoryCell.self,
            forCellReuseIdentifier: StatusHistoryCell.reuseIdentifier
        )
        view.addSubview(tableView)
        NSLayoutConstraint.activate([
            tableView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            tableView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            tableView.topAnchor.constraint(equalTo: view.topAnchor),
            tableView.bottomAnchor.constraint(equalTo: view.bottomAnchor)
        ])

        dataSource = UITableViewDiffableDataSource<Section, StatusHistoryRowModel>(
            tableView: tableView
        ) { tableView, indexPath, row in
            let cell = tableView.dequeueReusableCell(
                withIdentifier: StatusHistoryCell.reuseIdentifier,
                for: indexPath
            )
            (cell as? StatusHistoryCell)?.configure(with: row)
            return cell
        }
    }

    private func loadStatusChanges() {
        do {
            guard let application = try repository.application(id: applicationID) else {
                throw RepositoryError.loadFailed
            }
            let changes = try repository.statusChanges(for: application)
            let rows = changes.map { change in
                StatusHistoryRowModel(
                    id: change.id,
                    fromStatus: change.fromStatus,
                    toStatus: change.toStatus,
                    changedAt: change.changedAt,
                    note: change.note,
                    calendar: calendar,
                    locale: locale
                )
            }
            apply(rows)
        } catch {
            AppLogger.ui.error(
                "Failed to load status history: \(error.localizedDescription, privacy: .public)"
            )
            showLoadFailure()
        }
    }

    private func apply(_ rows: [StatusHistoryRowModel]) {
        var snapshot = NSDiffableDataSourceSnapshot<Section, StatusHistoryRowModel>()
        snapshot.appendSections([.main])
        snapshot.appendItems(rows, toSection: .main)
        dataSource.apply(snapshot, animatingDifferences: false)
        contentUnavailableConfiguration = rows.isEmpty ? makeEmptyConfiguration() : nil
    }

    private func showLoadFailure() {
        var snapshot = NSDiffableDataSourceSnapshot<Section, StatusHistoryRowModel>()
        snapshot.appendSections([.main])
        dataSource.apply(snapshot, animatingDifferences: false)
        contentUnavailableConfiguration = makeLoadFailureConfiguration()
    }

    private func makeEmptyConfiguration() -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "clock.arrow.circlepath")
        configuration.text = "还没有状态记录"
        return configuration
    }

    private func makeLoadFailureConfiguration() -> UIContentUnavailableConfiguration {
        var configuration = UIContentUnavailableConfiguration.empty()
        configuration.image = UIImage(systemName: "exclamationmark.triangle")
        configuration.text = "加载失败"
        configuration.secondaryText = "加载失败，请稍后重试"
        var button = UIButton.Configuration.borderedProminent()
        button.title = "重试"
        configuration.button = button
        configuration.buttonProperties.primaryAction = UIAction { [weak self] _ in
            self?.loadStatusChanges()
        }
        return configuration
    }
}
