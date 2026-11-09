import SwiftUI
import UIKit

/// Discover tab: persistent sample-mode header, paste-a-JD entry, refresh loop, internship filter,
/// and the eligibility-grouped job list with match explanations.
struct DiscoverView: View {
    @Environment(AppContainer.self) private var container
    @State private var viewModel: DiscoverViewModel?

    var body: some View {
        Group {
            if let viewModel {
                content(viewModel)
            } else {
                ProgressView("正在读取本地岗位…")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .background(Color(uiColor: .systemGroupedBackground))
        .navigationTitle("Discover")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            guard viewModel == nil else { return }
            let model = DiscoverViewModel(
                jobRepository: container.jobRepository,
                dateProvider: container.dateProvider,
                matchProvider: container.matchProvider
            )
            viewModel = model
            await model.loadAndRefreshIfNeeded()
        }
        .onAppear {
            // Returning from the import form or a detail refresh shows newly saved jobs.
            // Matches are recomputed on every cache read, never persisted.
            viewModel?.loadCachedJobs()
        }
    }

    private func content(_ viewModel: DiscoverViewModel) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                DiscoverSampleHeader(viewModel: viewModel)

                if let blocking = viewModel.blockingRefreshPrompt {
                    BlockingRefreshState(prompt: blocking) {
                        Task { await viewModel.refresh() }
                    }
                } else {
                    PasteJobCard()

                    if let notice = viewModel.refreshNotice {
                        RefreshNoticeCard(prompt: notice) {
                            Task { await viewModel.refresh() }
                        }
                    }

                    if case .failed = viewModel.cacheState {
                        CacheErrorCard(
                            message: viewModel.cacheErrorMessage ?? "加载失败，请稍后重试"
                        ) {
                            viewModel.loadCachedJobs()
                        }
                    } else if viewModel.isInitialLoading {
                        ProgressView("正在获取岗位…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 40)
                    } else {
                        OnlyInternshipsToggle(viewModel: viewModel)
                        GroupedJobsSection(
                            viewModel: viewModel,
                            skillDictionary: container.matchingLexicon?.skillDictionary
                        ) {
                            Task { await viewModel.refresh() }
                        }
                    }
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 28)
        }
        .refreshable {
            await viewModel.refresh()
        }
    }
}

// MARK: - Sample header

private struct DiscoverSampleHeader: View {
    let viewModel: DiscoverViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline) {
                Text("样本模式")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 9)
                    .padding(.vertical, 4)
                    .background(Capsule().fill(Color.accentColor.opacity(0.12)))
                    .foregroundStyle(Color.accentColor)
                Spacer()
                Text(viewModel.sampleDateText)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 3) {
                Text("Discover")
                    .font(.system(size: 36, weight: .bold))
                Text("今天的 Remotive 样本，和你手动粘贴的岗位。")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .top, spacing: 26) {
                    count(viewModel.remotiveCount, label: "Remotive 样本")
                    count(viewModel.remotiveInternshipCount, label: "其中实习")
                    count(viewModel.manualCount, label: "手动导入")
                }
                Text("公共 API 每天只放出一小份样本，不是全部岗位；条数少不是加载失败。")
                    .font(.footnote)
                    .opacity(0.72)
                if let summary = viewModel.lastRefreshSummary {
                    Text(summary)
                        .font(.caption2.weight(.semibold))
                        .opacity(0.72)
                }
                Text("数据来源 Remotive · \(viewModel.lastRefreshText) · 岗位回链原站")
                    .font(.caption2)
                    .opacity(0.55)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RoundedRectangle(cornerRadius: 20, style: .continuous).fill(Color(red: 0.11, green: 0.11, blue: 0.12)))
            .foregroundStyle(Color.white)
        }
    }

    private func count(_ value: Int, label: String) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("\(value)")
                .font(.system(size: 30, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .opacity(0.6)
        }
    }
}

// MARK: - Paste entry and filter

private struct PasteJobCard: View {
    var body: some View {
        NavigationLink(value: DiscoverRoute.manualImport) {
            HStack(spacing: 12) {
                Image(systemName: "doc.on.clipboard")
                    .font(.title3)
                    .frame(width: 38, height: 38)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor.opacity(0.12))
                    )
                    .foregroundStyle(Color.accentColor)
                VStack(alignment: .leading, spacing: 2) {
                    Text("粘贴一份 JD")
                        .font(.subheadline.weight(.semibold))
                    Text("本地匹配，不消耗 Remotive 配额")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "chevron.right")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.accentColor.opacity(0.06))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .strokeBorder(
                        Color.accentColor.opacity(0.4),
                        style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                    )
            )
        }
        .buttonStyle(.plain)
    }
}

private struct OnlyInternshipsToggle: View {
    @Bindable var viewModel: DiscoverViewModel

    var body: some View {
        Toggle(isOn: $viewModel.onlyInternships) {
            VStack(alignment: .leading, spacing: 2) {
                Text("只看实习")
                    .font(.subheadline.weight(.semibold))
                Text("只影响列表显示，不改变匹配")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .tint(.accentColor)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Jobs and states

private struct GroupedJobsSection: View {
    let viewModel: DiscoverViewModel
    let skillDictionary: SkillDictionary?
    let retry: () -> Void

    @ViewBuilder
    var body: some View {
        if viewModel.jobs.isEmpty {
            DiscoverEmptyState(retry: retry)
        } else if viewModel.visibleJobs.isEmpty {
            FilteredEmptyState(
                sampleCount: viewModel.remotiveCount,
                totalCount: viewModel.jobs.count
            ) {
                viewModel.onlyInternships = false
            }
        } else {
            VStack(alignment: .leading, spacing: 12) {
                EligibleGroup(
                    viewModel: viewModel,
                    skillDictionary: skillDictionary
                )
                IneligibleGroup(viewModel: viewModel)
            }
        }
    }
}

// MARK: - Eligible group

private struct EligibleGroup: View {
    let viewModel: DiscoverViewModel
    let skillDictionary: SkillDictionary?

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Text("适合你")
                    .font(.title3.bold())
                Spacer(minLength: 8)
                if viewModel.matchAvailability == .ready, !viewModel.eligibleJobs.isEmpty {
                    Text("\(viewModel.eligibleJobs.count) 条")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            if viewModel.eligibleJobs.isEmpty {
                EligibleInlineEmptyState()
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.eligibleJobs, id: \.job.id) { item in
                        NavigationLink(value: DiscoverRoute.jobDetail(jobID: item.job.id)) {
                            EligibleJobCard(
                                item: item,
                                availability: viewModel.matchAvailability,
                                skillDictionary: skillDictionary
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }
}

private struct EligibleJobCard: View {
    let item: DiscoverJobItem
    let availability: MatchAvailability
    let skillDictionary: SkillDictionary?

    private var job: JobPosting { item.job }

    private var presentation: MatchCardPresentation {
        MatchCardPresenter.eligible(
            match: item.match,
            availability: availability,
            dictionary: skillDictionary
        )
    }

    private var bandTint: Color {
        item.match?.band?.tint ?? .secondary
    }

    private var metadata: String {
        var parts: [String] = []
        if let location = job.location, !location.isEmpty {
            parts.append(location)
        }
        if let type = JobTypeOption.displayName(forJobType: job.jobType) {
            parts.append(type)
        }
        return parts.joined(separator: " · ")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 10) {
                CompanyInitials(name: job.companyName)

                VStack(alignment: .leading, spacing: 2) {
                    Text(job.companyName)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    Text(job.title)
                        .font(.subheadline.weight(.semibold))
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)
                }

                Spacer(minLength: 6)

                if let scoreText = presentation.scoreText {
                    MatchScorePill(text: scoreText, tint: bandTint)
                }
            }

            HStack(spacing: 6) {
                if !metadata.isEmpty {
                    Text(metadata)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                DiscoverSourceBadge(method: job.intakeMethod)
                if presentation.isLowConfidence {
                    Text("低置信度")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color.orange.opacity(0.15)))
                        .foregroundStyle(Color.orange)
                }
                Spacer(minLength: 0)
            }

            if let bandText = presentation.bandText {
                HStack(spacing: 6) {
                    Text(bandText)
                        .font(.caption.weight(.bold))
                        .foregroundStyle(bandTint)
                    if let countText = presentation.matchCountText {
                        Text("· \(countText)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !presentation.matchedTags.isEmpty || !presentation.missingTags.isEmpty {
                MatchSkillTagFlow(
                    tags: presentation.matchedTags + presentation.missingTags,
                    extraMatchedCount: presentation.extraMatchedCount,
                    extraMissingCount: presentation.extraMissingCount
                )
            }

            if let fallbackMessage = presentation.fallbackMessage, !fallbackMessage.isEmpty {
                Text(fallbackMessage)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(.secondary)
            } else if let reason = presentation.reason {
                Text(reason)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(Color(uiColor: .separator).opacity(0.35), lineWidth: 0.5)
        )
    }
}

// MARK: - Ineligible group

private struct IneligibleGroup: View {
    let viewModel: DiscoverViewModel

    var body: some View {
        if !viewModel.ineligibleJobs.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("不符合条件 · \(viewModel.ineligibleJobs.count) 条")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.secondary)
                    .padding(.top, 4)

                LazyVStack(spacing: 8) {
                    ForEach(viewModel.visibleIneligibleJobs, id: \.job.id) { item in
                        NavigationLink(value: DiscoverRoute.jobDetail(jobID: item.job.id)) {
                            IneligibleJobRow(
                                item: item,
                                availability: viewModel.matchAvailability
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }

                if viewModel.hasMoreIneligible {
                    Button {
                        viewModel.toggleIneligibleExpansion()
                    } label: {
                        Text(
                            viewModel.isShowingAllIneligible
                                ? "收起"
                                : "展开全部 \(viewModel.ineligibleJobs.count) 条"
                        )
                        .font(.subheadline.weight(.semibold))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(uiColor: .secondarySystemFill))
                        )
                        .foregroundStyle(.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct IneligibleJobRow: View {
    let item: DiscoverJobItem
    let availability: MatchAvailability

    private var job: JobPosting { item.job }

    private var presentation: IneligibleCardPresentation {
        MatchCardPresenter.ineligible(
            job: job,
            match: item.match,
            eligibility: item.eligibility,
            availability: availability
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .top, spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(job.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Text("\(job.companyName) · \(presentation.sourceText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
                Spacer(minLength: 6)
                Text("不符合")
                    .font(.caption2.weight(.bold))
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(Color.red.opacity(0.12)))
                    .foregroundStyle(Color.red)
            }

            HStack(spacing: 4) {
                Text(presentation.reasonText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.red)
                if let skillCountText = presentation.skillCountText {
                    Text("· \(skillCountText)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(11)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.red.opacity(0.18), lineWidth: 0.5)
        )
    }
}

private struct EligibleInlineEmptyState: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("这一批岗位里没有适合你的")
                .font(.subheadline.weight(.semibold))
            Text("条件不符的岗位仍然列在下方。也可以粘贴一份 JD，用本地匹配看看。")
                .font(.caption)
                .foregroundStyle(.secondary)
            NavigationLink(value: DiscoverRoute.manualImport) {
                Text("粘贴 JD")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(Color.accentColor.opacity(0.06))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .strokeBorder(
                    Color.accentColor.opacity(0.35),
                    style: StrokeStyle(lineWidth: 1, dash: [5, 4])
                )
        )
    }
}

// MARK: - Shared card pieces

private struct CompanyInitials: View {
    let name: String

    private var initials: String {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "?" : String(trimmed.prefix(2)).uppercased()
    }

    var body: some View {
        Text(initials)
            .font(.caption.weight(.bold))
            .frame(width: 34, height: 34)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(Color(uiColor: .tertiarySystemFill))
            )
            .foregroundStyle(.secondary)
    }
}

private struct DiscoverSourceBadge: View {
    let method: JobIntakeMethod

    private var color: Color {
        method == .remotive ? .secondary : .accentColor
    }

    var body: some View {
        Text(method.displayName)
            .font(.caption2.weight(.bold))
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(Capsule().fill(color.opacity(0.13)))
            .foregroundStyle(color)
            .lineLimit(1)
    }
}

private struct DiscoverEmptyState: View {
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "safari")
                .font(.system(size: 38))
                .foregroundStyle(Color.accentColor)
            Text("还没有岗位")
                .font(.title3.weight(.semibold))
            Text("公共 API 每天只放出一小份样本，不是全部岗位；条数少不是加载失败。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PasteJDButton()
                .padding(.top, 6)
            Button("重试", action: retry)
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: 280)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(uiColor: .secondarySystemFill))
                )
                .foregroundStyle(.primary)
                .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 8)
    }
}

private struct FilteredEmptyState: View {
    let sampleCount: Int
    let totalCount: Int
    let showAll: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Text("今天的样本里没有实习")
                .font(.headline)
            Text("Remotive 公共 API 每天只放出一小份样本，今天 \(sampleCount) 条里 0 条实习。这不是加载失败。")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            PasteJDButton()
                .padding(.top, 6)
            Button(action: showAll) {
                Text("查看全部 \(totalCount) 条岗位")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemFill))
                    )
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
            Text("手动导入的岗位会出现在这里；明天会有新样本。")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .padding(.horizontal, 8)
    }
}

private struct PasteJDButton: View {
    var body: some View {
        NavigationLink(value: DiscoverRoute.manualImport) {
            Text("粘贴 JD")
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color.accentColor)
                )
                .foregroundStyle(Color.white)
        }
        .buttonStyle(.plain)
        .frame(maxWidth: 280)
    }
}

private struct CacheErrorCard: View {
    let message: String
    let retry: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label("暂时读不到本地岗位", systemImage: "exclamationmark.triangle")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.orange)
            Text(message)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Button("重新加载", action: retry)
                .font(.subheadline.weight(.semibold))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

// MARK: - Refresh prompts

private struct RefreshNoticeCard: View {
    let prompt: DiscoverViewModel.RefreshPrompt
    let retry: () -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.orange)
                .padding(.top, 1)
            VStack(alignment: .leading, spacing: 3) {
                Text(prompt.title)
                    .font(.subheadline.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                if let message = prompt.message, !message.isEmpty {
                    Text(message)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 8)
            Button("重试", action: retry)
                .font(.subheadline.weight(.semibold))
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.orange.opacity(0.10))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.orange.opacity(0.28), lineWidth: 0.5)
        )
    }
}

private struct BlockingRefreshState: View {
    let prompt: DiscoverViewModel.RefreshPrompt
    let retry: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: "wifi.exclamationmark")
                .font(.system(size: 38))
                .foregroundStyle(.orange)
            Text(prompt.title)
                .font(.title3.weight(.semibold))
            if let message = prompt.message, !message.isEmpty {
                Text(message)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            Button(action: retry) {
                Text("重试")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: 280)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color.accentColor)
                    )
                    .foregroundStyle(Color.white)
            }
            .buttonStyle(.plain)
            .padding(.top, 4)

            NavigationLink(value: DiscoverRoute.manualImport) {
                Text("粘贴 JD")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: 280)
                    .padding(.vertical, 11)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(uiColor: .secondarySystemFill))
                    )
                    .foregroundStyle(.primary)
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color(uiColor: .secondarySystemGroupedBackground))
        )
    }
}

