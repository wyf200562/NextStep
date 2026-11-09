import Foundation
import Observation
import os

/// Owns the 我的 form: a `ProfileDraft` snapshot, live matching-gate hints, and the save state.
///
/// The ViewModel never touches `ModelContext`; it reads and writes the single `UserProfile`
/// through `UserProfileRepository`. An optional `MatchingLexicon` powers the skill picker; when the
/// lexicon is unavailable, skill selection is disabled while every other field stays editable.
@Observable
@MainActor
final class ProfileViewModel {
    private static let minimumResolvableSkills = 3

    private let repository: any UserProfileRepository
    private let lexicon: MatchingLexicon?
    private let dateProvider: any DateProvider

    var draft: ProfileDraft
    private var savedDraft: ProfileDraft
    private var profile: UserProfile?

    private(set) var loadErrorMessage: String?
    private(set) var saveErrorMessage: String?
    private(set) var isSaving = false

    init(
        repository: any UserProfileRepository,
        lexicon: MatchingLexicon?,
        dateProvider: any DateProvider = SystemDateProvider()
    ) {
        self.repository = repository
        self.lexicon = lexicon
        self.dateProvider = dateProvider
        self.draft = ProfileDraft()
        self.savedDraft = ProfileDraft()
        load()
    }

    /// True when dismissing the page would lose edits that were not saved.
    var hasUnsavedChanges: Bool {
        draft != savedDraft
    }

    // MARK: - Dictionary availability

    /// Whether the skill picker can be used; the bundled lexicon may fail to load.
    var isSkillPickerEnabled: Bool {
        lexicon != nil
    }

    /// Copy shown in place of the skill picker when the lexicon is unavailable.
    var skillAvailabilityMessage: String? {
        lexicon == nil ? "技能词典暂不可用" : nil
    }

    /// Every skill in the loaded dictionary, grouped by category in the picker.
    var allSkills: [Skill]? {
        lexicon?.skillDictionary.skills
    }

    // MARK: - Matching gate hints

    /// Live hint for the skill gate. `nil` once three skills resolve or when the lexicon is
    /// unavailable (the picker shows the dictionary-unavailable message instead).
    var skillGateHint: String? {
        guard lexicon != nil else { return nil }
        let remaining = max(0, Self.minimumResolvableSkills - resolvableSkillCount)
        guard remaining > 0 else { return nil }
        return "再选 \(remaining) 个技能后才会计算匹配"
    }

    /// Live hint for the target-role gate. `nil` once at least one non-blank role exists.
    var targetRoleGateHint: String? {
        let hasTargetRole = draft.targetRoles.contains { TagList.normalized($0) != nil }
        return hasTargetRole ? nil : "填写目标方向后才会计算匹配"
    }

    // MARK: - Free-text tags

    func addTargetRole(_ text: String) {
        draft.targetRoles = TagList.appending(text, to: draft.targetRoles)
    }

    func removeTargetRole(_ role: String) {
        draft.targetRoles = TagList.removing(role, from: draft.targetRoles)
    }

    func addPreferredLocation(_ text: String) {
        draft.preferredLocations = TagList.appending(text, to: draft.preferredLocations)
    }

    func removePreferredLocation(_ location: String) {
        draft.preferredLocations = TagList.removing(location, from: draft.preferredLocations)
    }

    // MARK: - Skills

    private var skillDictionary: SkillDictionary? {
        lexicon?.skillDictionary
    }

    /// Number of selected skills shown in the form.
    var selectedSkillCount: Int {
        draft.skills.count
    }

    /// Number of selected skills that resolve to a dictionary entry.
    var resolvableSkillCount: Int {
        resolvedSkillIDs.count
    }

    private var resolvedSkillIDs: Set<SkillID> {
        guard let skillDictionary else { return [] }
        return Set(draft.skills.compactMap { skillDictionary.skill(named: $0)?.id })
    }

    /// Resolves a canonical dictionary name case-insensitively and appends it once.
    ///
    /// Unknown names and duplicates are ignored. Returns whether the selection changed.
    @discardableResult
    func addSkill(named rawName: String) -> Bool {
        guard let skillDictionary, let skill = skillDictionary.skill(named: rawName) else {
            return false
        }
        guard !resolvedSkillIDs.contains(skill.id) else { return false }
        draft.skills.append(skill.name)
        return true
    }

    func toggleSkill(_ skill: Skill) {
        guard let skillDictionary else { return }
        if let index = draft.skills.firstIndex(where: {
            skillDictionary.skill(named: $0)?.id == skill.id
        }) {
            draft.skills.remove(at: index)
        } else {
            draft.skills.append(skill.name)
        }
    }

    func isSkillSelected(_ skill: Skill) -> Bool {
        resolvedSkillIDs.contains(skill.id)
    }

    func removeSkill(named rawName: String) {
        guard let skillDictionary, let skill = skillDictionary.skill(named: rawName) else {
            draft.skills.removeAll { $0 == rawName }
            return
        }
        draft.skills.removeAll { skillDictionary.skill(named: $0)?.id == skill.id }
    }

    /// Loads the single profile via fetch-or-create and resets the draft baseline.
    func load() {
        do {
            let profile = try repository.fetchOrCreateProfile()
            self.profile = profile

            let loaded = ProfileDraft(
                skills: canonicalSkills(from: profile.skills),
                targetRoles: profile.targetRoles,
                preferredLocations: profile.preferredLocations,
                timeZoneIdentifier: profile.timeZoneIdentifier ?? TimeZone.current.identifier,
                availableFrom: profile.availableFrom,
                availableUntil: profile.availableUntil,
                graduationYear: profile.graduationYear
            )
            draft = loaded
            savedDraft = loaded
            loadErrorMessage = nil
            saveErrorMessage = nil
        } catch {
            AppLogger.ui.error(
                "Failed to load the UserProfile: \(error.localizedDescription, privacy: .public)"
            )
            loadErrorMessage = "加载失败，请稍后重试"
        }
    }

    /// Writes the draft back through the repository. Empty fields are allowed.
    func save() {
        guard !isSaving else { return }
        guard let profile else {
            saveErrorMessage = "保存失败，请重试"
            return
        }

        isSaving = true
        defer { isSaving = false }

        let previous = ProfileDraft(
            skills: profile.skills,
            targetRoles: profile.targetRoles,
            preferredLocations: profile.preferredLocations,
            timeZoneIdentifier: profile.timeZoneIdentifier ?? TimeZone.current.identifier,
            availableFrom: profile.availableFrom,
            availableUntil: profile.availableUntil,
            graduationYear: profile.graduationYear
        )
        apply(draft, to: profile)

        do {
            try repository.save(profile)
            savedDraft = draft
            saveErrorMessage = nil
        } catch {
            apply(previous, to: profile)
            AppLogger.ui.error(
                "Failed to save the UserProfile: \(error.localizedDescription, privacy: .public)"
            )
            saveErrorMessage = "保存失败，请重试"
        }
    }

    // MARK: - Display helpers

    /// Common time zones plus the draft's current identifier, for the picker.
    var timeZoneChoices: [TimeZoneOption] {
        TimeZoneCatalog.options(including: draft.timeZoneIdentifier)
    }

    /// Digits-only text for the optional graduation year field; blank maps to `nil`.
    var graduationYearText: String {
        get { draft.graduationYear.map(String.init) ?? "" }
        set {
            let digits = String(newValue.filter(\.isNumber).prefix(4))
            draft.graduationYear = digits.isEmpty ? nil : Int(digits)
        }
    }

    func setAvailableFromEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if draft.availableFrom == nil {
                draft.availableFrom = dateProvider.now
            }
        } else {
            draft.availableFrom = nil
        }
    }

    func setAvailableUntilEnabled(_ isEnabled: Bool) {
        if isEnabled {
            if draft.availableUntil == nil {
                draft.availableUntil = dateProvider.now
            }
        } else {
            draft.availableUntil = nil
        }
    }

    /// Drops unsaved edits and restores the last saved snapshot.
    func discardChanges() {
        draft = savedDraft
        saveErrorMessage = nil
    }

    /// Stores only canonical dictionary names, deduplicated by id and in first-seen order.
    /// Unknown names are ignored (the matching engine ignores them too).
    private func canonicalSkills(from rawSkills: [String]) -> [String] {
        guard let skillDictionary else { return rawSkills }

        var seen: Set<SkillID> = []
        var result: [String] = []
        for rawName in rawSkills {
            let name = rawName.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { continue }
            guard let skill = skillDictionary.skill(named: name) else {
                AppLogger.matching.debug(
                    "Unknown profile skill '\(name, privacy: .public)' ignored"
                )
                continue
            }
            guard seen.insert(skill.id).inserted else { continue }
            result.append(skill.name)
        }
        return result
    }

    private func apply(_ draft: ProfileDraft, to profile: UserProfile) {
        profile.skills = draft.skills
        profile.targetRoles = draft.targetRoles
        profile.preferredLocations = draft.preferredLocations
        profile.timeZoneIdentifier = draft.timeZoneIdentifier
        profile.availableFrom = draft.availableFrom
        profile.availableUntil = draft.availableUntil
        profile.graduationYear = draft.graduationYear
    }
}
