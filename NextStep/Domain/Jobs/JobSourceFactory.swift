import Foundation

/// Builds the concrete job source for each input. Keeping construction behind this value lets tests
/// inject fakes and keeps ViewModels away from source types.
nonisolated struct JobSourceFactory: Sendable {
    let makeRemote: @Sendable (JobQuery) -> any JobSource
    let makeManual: @Sendable (ManualJobInput) -> any JobSource
}
