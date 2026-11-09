import Foundation
import SwiftData

/// An append-only record of one application status transition.
///
/// Creating an application writes the first record with `fromStatus == nil`. Only status changes
/// create records; editing notes, deadlines, or rounds updates `Application.lastModifiedAt` instead.
@Model
final class StatusChange {
    var id: UUID
    var fromStatusRaw: String?
    var toStatusRaw: String
    var changedAt: Date
    var note: String?
    var application: Application?

    /// Typed view over `fromStatusRaw`; `nil` marks the initial creation record.
    var fromStatus: ApplicationStatus? {
        get {
            guard let fromStatusRaw else { return nil }
            return ApplicationStatus(rawValue: fromStatusRaw)
        }
        set { fromStatusRaw = newValue?.rawValue }
    }

    /// Typed view over `toStatusRaw`.
    var toStatus: ApplicationStatus {
        get { ApplicationStatus(rawValue: toStatusRaw) ?? .wishlist }
        set { toStatusRaw = newValue.rawValue }
    }

    init(
        id: UUID = UUID(),
        fromStatus: ApplicationStatus? = nil,
        toStatus: ApplicationStatus,
        changedAt: Date,
        note: String? = nil
    ) {
        self.id = id
        self.fromStatusRaw = fromStatus?.rawValue
        self.toStatusRaw = toStatus.rawValue
        self.changedAt = changedAt
        self.note = note
    }
}
