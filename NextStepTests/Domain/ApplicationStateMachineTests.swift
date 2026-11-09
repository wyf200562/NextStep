import Foundation
import Testing
@testable import NextStep

/// Table-driven coverage of the spec §2 status transition table.
///
/// The expected sets below are transcribed from the spec, not derived from the implementation, so
/// the tests fail if the transition table drifts in either direction.
@Suite("ApplicationStateMachine")
struct ApplicationStateMachineTests {
    nonisolated struct Transition: Sendable, CustomTestStringConvertible {
        let from: ApplicationStatus
        let to: ApplicationStatus

        var testDescription: String { "\(from.rawValue)→\(to.rawValue)" }
    }

    /// Normal (non-reopen) transitions from spec §2. Terminal states have no normal exits.
    private static let normalTransitions: [ApplicationStatus: Set<ApplicationStatus>] = [
        .wishlist: [.applied, .withdrawn],
        .applied: [.wishlist, .oa, .interview, .offer, .rejected, .withdrawn],
        .oa: [.wishlist, .applied, .interview, .offer, .rejected, .withdrawn],
        .interview: [.wishlist, .applied, .oa, .offer, .rejected, .withdrawn],
        .offer: [],
        .rejected: [],
        .withdrawn: [],
    ]

    /// Reopen transitions from spec §2. Only terminated states can be reopened.
    private static let reopenTransitions: [ApplicationStatus: Set<ApplicationStatus>] = [
        .wishlist: [],
        .applied: [],
        .oa: [],
        .interview: [],
        .offer: [],
        .rejected: [.applied, .oa, .interview, .offer],
        .withdrawn: [.wishlist, .applied, .oa, .interview, .offer],
    ]

    /// Backward moves among active states that the UI must confirm.
    private static let backwardActiveTransitions: Set<TransitionKey> = [
        TransitionKey(from: .applied, to: .wishlist),
        TransitionKey(from: .oa, to: .wishlist),
        TransitionKey(from: .oa, to: .applied),
        TransitionKey(from: .interview, to: .wishlist),
        TransitionKey(from: .interview, to: .applied),
        TransitionKey(from: .interview, to: .oa),
    ]

    nonisolated struct TransitionKey: Hashable, Sendable {
        let from: ApplicationStatus
        let to: ApplicationStatus
    }

    private nonisolated static let allPairs: [Transition] = ApplicationStatus.allCases.flatMap { from in
        ApplicationStatus.allCases.map { Transition(from: from, to: $0) }
    }

    private static func expectedAllowed(from status: ApplicationStatus) -> Set<ApplicationStatus> {
        normalTransitions[status, default: []].union(reopenTransitions[status, default: []])
    }

    @Test("allowedTransitions is normal plus reopen targets", arguments: ApplicationStatus.allCases)
    func allowedTransitionsMatchSpecTable(from status: ApplicationStatus) {
        let targets = ApplicationStateMachine.allowedTransitions(from: status)

        #expect(Set(targets) == Self.expectedAllowed(from: status))
        #expect(targets.count == Set(targets).count, "targets must not repeat")
    }

    @Test("reopenTargets is non-empty only for terminated states", arguments: ApplicationStatus.allCases)
    func reopenTargetsMatchSpecTable(from status: ApplicationStatus) {
        #expect(
            Set(ApplicationStateMachine.reopenTargets(from: status))
                == Self.reopenTransitions[status, default: []]
        )
    }

    @Test("isValidTransition accepts exactly the allowed pairs", arguments: Self.allPairs)
    func isValidTransitionMatchesAllowedPairs(pair: Transition) {
        let expected = Self.expectedAllowed(from: pair.from).contains(pair.to)

        #expect(
            ApplicationStateMachine.isValidTransition(from: pair.from, to: pair.to) == expected,
            "\(pair.testDescription) should be \(expected ? "valid" : "invalid")"
        )
    }

    @Test("requiresConfirmation is true for backward moves and reopens only", arguments: Self.allPairs)
    func requiresConfirmationMatchesSpec(pair: Transition) {
        let isBackward = Self.backwardActiveTransitions.contains(
            TransitionKey(from: pair.from, to: pair.to)
        )
        let isReopen = Self.reopenTransitions[pair.from, default: []].contains(pair.to)
        let expected = isBackward || isReopen

        #expect(
            ApplicationStateMachine.requiresConfirmation(from: pair.from, to: pair.to) == expected,
            "\(pair.testDescription) confirmation should be \(expected)"
        )
    }

    @Test("forward transitions allow skipping stages")
    func forwardTransitionsAllowSkippingStages() {
        #expect(ApplicationStateMachine.isValidTransition(from: .wishlist, to: .applied))
        #expect(ApplicationStateMachine.isValidTransition(from: .applied, to: .offer))
        #expect(ApplicationStateMachine.isValidTransition(from: .applied, to: .interview))
        #expect(ApplicationStateMachine.isValidTransition(from: .oa, to: .offer))
        #expect(ApplicationStateMachine.isValidTransition(from: .interview, to: .offer))
        #expect(!ApplicationStateMachine.requiresConfirmation(from: .applied, to: .offer))
        #expect(!ApplicationStateMachine.requiresConfirmation(from: .wishlist, to: .applied))
    }

    @Test("offer is a success terminal with no exits")
    func offerHasNoExits() {
        #expect(ApplicationStateMachine.allowedTransitions(from: .offer).isEmpty)
        #expect(ApplicationStateMachine.reopenTargets(from: .offer).isEmpty)
        for target in ApplicationStatus.allCases {
            #expect(!ApplicationStateMachine.isValidTransition(from: .offer, to: target))
            #expect(!ApplicationStateMachine.requiresConfirmation(from: .offer, to: target))
        }
    }

    @Test("rejected and withdrawn are terminal in normal transitions but can be reopened")
    func terminatedStatesReopenOnlyThroughExplicitTargets() {
        #expect(ApplicationStateMachine.reopenTargets(from: .rejected) == [.applied, .oa, .interview, .offer])
        #expect(ApplicationStateMachine.reopenTargets(from: .withdrawn) == [.wishlist, .applied, .oa, .interview, .offer])

        // Reopen targets are valid and confirmed.
        for target in ApplicationStateMachine.reopenTargets(from: .rejected) {
            #expect(ApplicationStateMachine.isValidTransition(from: .rejected, to: target))
            #expect(ApplicationStateMachine.requiresConfirmation(from: .rejected, to: target))
        }
        for target in ApplicationStateMachine.reopenTargets(from: .withdrawn) {
            #expect(ApplicationStateMachine.isValidTransition(from: .withdrawn, to: target))
            #expect(ApplicationStateMachine.requiresConfirmation(from: .withdrawn, to: target))
        }

        // Not every status is a reopen target.
        #expect(!ApplicationStateMachine.isValidTransition(from: .rejected, to: .wishlist))
        #expect(!ApplicationStateMachine.isValidTransition(from: .rejected, to: .rejected))
        #expect(!ApplicationStateMachine.isValidTransition(from: .rejected, to: .withdrawn))
        #expect(!ApplicationStateMachine.isValidTransition(from: .withdrawn, to: .rejected))
        #expect(!ApplicationStateMachine.isValidTransition(from: .withdrawn, to: .withdrawn))
    }

    @Test("a status cannot transition to itself")
    func selfTransitionsAreInvalid() {
        for status in ApplicationStatus.allCases {
            #expect(!ApplicationStateMachine.isValidTransition(from: status, to: status))
        }
    }
}
