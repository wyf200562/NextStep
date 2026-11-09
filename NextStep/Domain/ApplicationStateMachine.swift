import Foundation

/// A status change rejected by `ApplicationStateMachine`.
///
/// The repository throws this typed error and the presentation layer maps it to the Chinese
///「当前状态不能这样变更」copy; raw error descriptions are never shown to users.
nonisolated struct ApplicationTransitionError: Error, Equatable, Sendable {
    let from: ApplicationStatus
    let to: ApplicationStatus
}

/// Pure transition rules for `ApplicationStatus`. No I/O, no persistence, no UI.
///
/// This is the single source of truth for which status changes are legal. Both
/// `ApplicationRepository.changeStatus` and the status-change sheet consume these functions, so the
/// transition table is never duplicated outside this type.
nonisolated enum ApplicationStateMachine {
    private struct Transition: Hashable {
        let from: ApplicationStatus
        let to: ApplicationStatus
    }

    /// Normal moves from the spec §2 table. `offer`, `rejected`, and `withdrawn` have no normal exits.
    private static let normalTransitions: [ApplicationStatus: Set<ApplicationStatus>] = [
        .wishlist: [.applied, .withdrawn],
        .applied: [.wishlist, .oa, .interview, .offer, .rejected, .withdrawn],
        .oa: [.wishlist, .applied, .interview, .offer, .rejected, .withdrawn],
        .interview: [.wishlist, .applied, .oa, .offer, .rejected, .withdrawn],
        .offer: [],
        .rejected: [],
        .withdrawn: [],
    ]

    /// Explicit "重新打开" moves out of terminated states.
    private static let reopenTransitions: [ApplicationStatus: Set<ApplicationStatus>] = [
        .wishlist: [],
        .applied: [],
        .oa: [],
        .interview: [],
        .offer: [],
        .rejected: [.applied, .oa, .interview, .offer],
        .withdrawn: [.wishlist, .applied, .oa, .interview, .offer],
    ]

    /// Backward moves between active states that require a second confirmation.
    private static let backwardActiveTransitions: Set<Transition> = [
        Transition(from: .applied, to: .wishlist),
        Transition(from: .oa, to: .wishlist),
        Transition(from: .oa, to: .applied),
        Transition(from: .interview, to: .wishlist),
        Transition(from: .interview, to: .applied),
        Transition(from: .interview, to: .oa),
    ]

    /// Every target accepted by `changeStatus`: normal transitions plus reopen targets, in the
    /// canonical `ApplicationStatus.allCases` order.
    static func allowedTransitions(from status: ApplicationStatus) -> [ApplicationStatus] {
        let normal = normalTransitions[status, default: []]
        let reopen = reopenTransitions[status, default: []]
        return ApplicationStatus.allCases.filter { normal.contains($0) || reopen.contains($0) }
    }

    /// Targets available only through the explicit reopen flow; empty for non-terminated states.
    static func reopenTargets(from status: ApplicationStatus) -> [ApplicationStatus] {
        let reopen = reopenTransitions[status, default: []]
        return ApplicationStatus.allCases.filter { reopen.contains($0) }
    }

    /// Accepts exactly the normal and reopen edges; every other pair is illegal.
    static func isValidTransition(from: ApplicationStatus, to: ApplicationStatus) -> Bool {
        normalTransitions[from, default: []].contains(to)
            || reopenTransitions[from, default: []].contains(to)
    }

    /// True for backward moves among active states and for every reopen.
    static func requiresConfirmation(from: ApplicationStatus, to: ApplicationStatus) -> Bool {
        guard isValidTransition(from: from, to: to) else { return false }
        if reopenTransitions[from, default: []].contains(to) { return true }
        return backwardActiveTransitions.contains(Transition(from: from, to: to))
    }
}
