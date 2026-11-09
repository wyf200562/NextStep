import SwiftUI

/// Job detail: header facts, plain-text JD, source/backlink, and the import CTA.
///
/// Match explanation (gate, score hero, skills, JD highlighting) is ticket 22; the insertion point
/// between the header and the JD is marked below. Navigation stays in this view: the ViewModel only
/// returns application ids and the router performs cross-tab pushes.
struct JobDetailView: View {
    @Environment(AppContainer.self) private var container

    @State private var viewModel: JobDetailViewModel
    @State private var didLoad = false
    @State private var isConfirmingReimport = false

    init(container: AppContainer, jobID: UUID) {
        _viewModel = State(initialValue: JobDetailViewModel(
            jobRepository: container.jobRepository,
            applicationRepository: container.applicationRepository,
            dateProvider: container.dateProvider,
            jobID: jobID,
            matchProvider: container.matchProvider
        ))
    }

    var body: some View {
        content(viewModel)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle("岗位详情")
            .navigationBarTitleDisplayMode(.inline)
            .task {
                guard !didLoad else { return }
                didLoad = true
                viewModel.load()
            }
            .confirmationDialog(
                "再次导入为申请？",
                isPresented: $isConfirmingReimport,
                titleVisibility: .visible
            ) {
                Button("再次导入") {
                    performImport(confirmed: true, viewModel: viewModel)
                }
                Button("取消", role: .cancel) {}
            } message: {
                Text("这个岗位已有已结束的申请。导入会新建一条申请记录，不会修改旧记录。")
            }
            .alert("操作失败", isPresented: importErrorBinding) {
                Button("好", role: .cancel) {
                    viewModel.clearImportError()
                }
            } message: {
                Text(viewModel.importErrorMessage ?? "")
            }
    }

    // MARK: - States

    @ViewBuilder
    private func content(_ viewModel: JobDetailViewModel) -> some View {
        switch viewModel.state {
        case .idle, .loading:
            ProgressView("正在加载…")
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        case .failed:
            failureState(viewModel)
        case .loaded(let job):
            loadedContent(job, viewModel: viewModel)
        }
    }

    private func loadedContent(
        _ job: JobPosting,
        viewModel: JobDetailViewModel
    ) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                JobHeaderCard(job: job)

                JobMatchSection(
                    availability: viewModel.matchAvailability,
                    match: viewModel.matchResult,
                    skillDictionary: container.matchingLexicon?.skillDictionary
                ) {
                    container.router.openProfile()
                }

                JobDescriptionCard(job: job, highlightSegments: jdHighlightSegments(job, viewModel: viewModel))
                JobSourceCard(job: job, remotiveSampleCount: viewModel.remotiveSampleCount)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 16)
        }
        .safeAreaInset(edge: .bottom) {
            ImportCTABar(viewModel: viewModel) {
                handleImportTapped(viewModel)
            }
        }
    }

    /// JD highlighting is display-only and only exists when a match result was computed.
    private func jdHighlightSegments(
        _ job: JobPosting,
        viewModel: JobDetailViewModel
    ) -> [JDHighlightSegment]? {
        guard viewModel.matchAvailability == .ready, let match = viewModel.matchResult else {
            return nil
        }
        let dictionary = container.matchingLexicon?.skillDictionary
        return JDHighlighter.segments(
            text: job.descriptionPlainText,
            matchedAliases: JDHighlighter.aliases(for: match.matchedSkills, dictionary: dictionary),
            missingAliases: JDHighlighter.aliases(for: match.missingSkills, dictionary: dictionary)
        )
    }

    private func failureState(_ viewModel: JobDetailViewModel) -> some View {
        ContentUnavailableView {
            Label("加载失败", systemImage: "exclamationmark.triangle")
        } description: {
            Text(viewModel.loadErrorMessage ?? "加载失败，请稍后重试")
        } actions: {
            Button("重试") {
                viewModel.load()
            }
            .buttonStyle(.borderedProminent)
        }
    }

    // MARK: - Import intents

    private func handleImportTapped(_ viewModel: JobDetailViewModel) {
        switch viewModel.importAction {
        case .viewExisting(let applicationID):
            container.router.openApplication(applicationID)
        case .importNew:
            performImport(confirmed: false, viewModel: viewModel)
        case .importAgain:
            isConfirmingReimport = true
        }
    }

    private func performImport(confirmed: Bool, viewModel: JobDetailViewModel) {
        guard let applicationID = viewModel.importApplication(confirmed: confirmed) else { return }
        container.router.openApplication(applicationID)
    }

    private var importErrorBinding: Binding<Bool> {
        Binding(
            get: { viewModel.importErrorMessage != nil },
            set: { isPresented in
                if !isPresented {
                    viewModel.clearImportError()
                }
            }
        )
    }
}

// MARK: - Cards

struct DetailCard<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(uiColor: .secondarySystemGroupedBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
            )
    }
}

private struct JobHeaderCard: View {
    let job: JobPosting

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(job.companyName)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(job.title)
                            .font(.title2.bold())
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    Spacer(minLength: 8)
                    SourceBadge(method: job.intakeMethod)
                }

                VStack(alignment: .leading, spacing: 7) {
                    if let location = job.location, !location.isEmpty {
                        fact(location, systemImage: "mappin.and.ellipse")
                    }
                    if let jobType = JobTypeOption.displayName(forJobType: job.jobType) {
                        fact(jobType, systemImage: "briefcase")
                    }
                    if let publishedAt = job.publishedAt {
                        fact(
                            "发布于 \(ApplicationDateFormatting.monthDay(publishedAt))",
                            systemImage: "calendar"
                        )
                    }
                    if let salary = job.salary, !salary.isEmpty {
                        fact(salary, systemImage: "banknote")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if !job.tags.isEmpty {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(job.tags, id: \.self) { tag in
                                Text(tag)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Capsule().fill(Color(uiColor: .tertiarySystemFill)))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
        }
    }

    private func fact(_ text: String, systemImage: String) -> some View {
        Label {
            Text(text)
        } icon: {
            Image(systemName: systemImage)
                .foregroundStyle(Color.accentColor)
        }
    }
}

private struct SourceBadge: View {
    let method: JobIntakeMethod

    private var color: Color {
        method == .remotive ? .secondary : .accentColor
    }

    var body: some View {
        Text(method.displayName)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(color.opacity(0.13)))
            .foregroundStyle(color)
    }
}

private struct JobDescriptionCard: View {
    let job: JobPosting
    /// `nil` when no match result exists (profile gate or matching unavailable); plain text then.
    let highlightSegments: [JDHighlightSegment]?

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 10) {
                Text("岗位描述")
                    .font(.headline)

                if job.descriptionPlainText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("暂无 JD 正文")
                        .foregroundStyle(.secondary)
                } else if let highlightSegments {
                    JDHighlightedText(segments: highlightSegments)
                } else {
                    Text(job.descriptionPlainText)
                        .font(.body)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

private struct JobSourceCard: View {
    let job: JobPosting
    let remotiveSampleCount: Int

    private var remotiveSampleText: String {
        remotiveSampleCount > 0
            ? "数据来源 Remotive · 本机 \(remotiveSampleCount) 条样本之一"
            : "数据来源 Remotive · 本机样本之一"
    }

    var body: some View {
        DetailCard {
            VStack(alignment: .leading, spacing: 8) {
                Text("来源")
                    .font(.headline)

                switch job.intakeMethod {
                case .remotive:
                    Text(remotiveSampleText)
                        .font(.subheadline)
                    Text("本机样本不代表 Remotive 全量岗位。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .manual:
                    Text("手动导入")
                        .font(.subheadline)
                    Text("这条岗位由你粘贴 JD 导入，仅保存在本机。")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                case .url:
                    Text("链接导入")
                        .font(.subheadline)
                }

                if let jobURL = job.jobURL {
                    Link(destination: jobURL) {
                        Label("打开原岗位", systemImage: "arrow.up.right.square")
                    }
                    .font(.subheadline.weight(.semibold))
                }
            }
        }
    }
}

// MARK: - Import CTA

private struct ImportCTABar: View {
    let viewModel: JobDetailViewModel
    let onTap: () -> Void

    var body: some View {
        VStack(spacing: 8) {
            if case .viewExisting = viewModel.importAction {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("已有进行中的申请")
                            .font(.subheadline.weight(.semibold))
                        Text("不会重复创建记录")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 8)
                    Button("查看", action: onTap)
                        .buttonStyle(.borderedProminent)
                        .controlSize(.large)
                }
            } else {
                if viewModel.importRequiresConfirmation {
                    Text("此岗位已有已结束的申请，导入会新建一条记录。")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                Button(action: onTap) {
                    HStack(spacing: 8) {
                        if viewModel.isImporting {
                            ProgressView()
                                .tint(.white)
                        }
                        Text(viewModel.importRequiresConfirmation ? "再次导入为申请" : "导入为申请")
                            .font(.headline)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 13)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(Color.white)
                }
                .buttonStyle(.plain)
                .disabled(viewModel.isImporting)
            }
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 12)
        .background(.bar)
    }
}
